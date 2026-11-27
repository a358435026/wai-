import Foundation

public enum TradeTerminology {
    public static let examples = "额定功率\trated power\n交货期\tlead time\n最小起订量\tminimum order quantity"
    // Editable starter vocabulary, not a certification or a downloaded proprietary dictionary.
    private static let rows = [
        ["电动车", "electric vehicle", "veículo elétrico", "vehículo eléctrico"],
        ["电动自行车", "electric bicycle", "bicicleta elétrica", "bicicleta eléctrica"],
        ["电动摩托车", "electric motorcycle", "motociclo elétrico", "motocicleta eléctrica"],
        ["锂离子电池", "lithium-ion battery", "bateria de iões de lítio", "batería de iones de litio"],
        ["电池容量", "battery capacity", "capacidade da bateria", "capacidad de la batería"],
        ["额定功率", "rated power", "potência nominal", "potencia nominal"],
        ["峰值功率", "peak power", "potência máxima", "potencia máxima"],
        ["续航里程", "range", "autonomia", "autonomía"],
        ["无刷电机", "brushless motor", "motor sem escovas", "motor sin escobillas"],
        ["轮毂电机", "hub motor", "motor no cubo", "motor de buje"],
        ["控制器", "controller", "controlador", "controlador"],
        ["充电器", "charger", "carregador", "cargador"],
        ["碟刹", "disc brake", "travão de disco", "freno de disco"],
        ["电池管理系统", "battery management system", "sistema de gestão da bateria", "sistema de gestión de la batería"],
        ["最小起订量", "minimum order quantity", "quantidade mínima de encomenda", "cantidad mínima de pedido"],
        ["交货期", "lead time", "prazo de entrega", "plazo de entrega"],
        ["样品费", "sample fee", "custo da amostra", "coste de la muestra"],
        ["质保期", "warranty period", "período de garantia", "período de garantía"],
        ["备件", "spare parts", "peças sobresselentes", "piezas de repuesto"],
        ["装箱单", "packing list", "lista de embalagem", "lista de empaque"],
        ["商业发票", "commercial invoice", "fatura comercial", "factura comercial"],
        ["提单", "bill of lading", "conhecimento de embarque", "conocimiento de embarque"],
        ["海运费", "ocean freight", "frete marítimo", "flete marítimo"],
        ["清关", "customs clearance", "desalfandegamento", "despacho de aduanas"],
        ["目的港", "port of destination", "porto de destino", "puerto de destino"],
        ["整柜", "full container load", "carga de contentor completo", "carga de contenedor completo"],
        ["拼箱", "less than container load", "carga fracionada", "carga consolidada"],
        ["付款条件", "payment terms", "condições de pagamento", "condiciones de pago"],
        ["报价单", "quotation", "orçamento", "cotización"],
        ["原产地证", "certificate of origin", "certificado de origem", "certificado de origen"]
    ]
    public static func preset(source: String, target: String) -> [String: String] {
        let codes = ["zh", "en", "pt", "es"]
        guard let output = codes.firstIndex(of: target) else { return [:] }
        let inputs = source == "bailian-auto" ? codes : source == "auto" ? ["zh", "en"] : [source]
        var result: [String: String] = [:]
        for input in inputs where input != target {
            guard let index = codes.firstIndex(of: input) else { continue }
            for row in rows { result[row[index]] = row[output] }
        }
        return result
    }
    public static func parse(_ input: String) throws -> [String: String] {
        guard input.utf8.count <= 32_000 else { throw BailianError("术语文件超过32KB，请保留本次会用到的词。") }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{feff}", with: "")
        if text.isEmpty { return [:] }
        var result: [String: String] = [:]
        if text.hasPrefix("{") {
            guard let value = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String] else {
                throw BailianError("JSON需为原文到译文的对象，例如 {\"交货期\":\"lead time\"}。")
            }
            result = value
        } else {
            for (index, line) in text.components(separatedBy: .newlines).enumerated() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let delimiter: Character = line.contains("\t") ? "\t" : ","
                let cells = try split(line, delimiter: delimiter)
                guard cells.count == 2 else { throw BailianError("第\(index + 1)行需为两列：原文与译文，用Tab或逗号分隔。") }
                let key = cells[0].trimmingCharacters(in: .whitespaces)
                let value = cells[1].trimmingCharacters(in: .whitespaces)
                if index == 0 && ["source", "原文"].contains(key.lowercased()) && ["target", "译文"].contains(value.lowercased()) { continue }
                if let old = result[key], old != value { throw BailianError("术语“\(key)”重复且译文不同，请合并后再导入。") }
                result[key] = value
            }
        }
        guard result.count <= 100 else { throw BailianError("自定义术语最多100条，请按业务场景拆分。") }
        guard result.allSatisfy({ !$0.key.isEmpty && !$0.value.isEmpty && $0.key.count <= 80 && $0.value.count <= 120 }) else {
            throw BailianError("术语原文/译文不能为空，原文最多80字，译文最多120字。")
        }
        return result
    }
    private static func split(_ line: String, delimiter: Character) throws -> [String] {
        let chars = Array(line); var index = 0; var quoted = false; var value = ""; var cells: [String] = []
        while index < chars.count {
            let c = chars[index]
            if c == "\"" {
                if quoted && index + 1 < chars.count && chars[index + 1] == "\"" { value.append("\""); index += 1 }
                else { quoted.toggle() }
            } else if c == delimiter && !quoted { cells.append(value); value = "" }
            else { value.append(c) }
            index += 1
        }
        guard !quoted else { throw BailianError("CSV引号未配对；请使用两列CSV、Tab文本或JSON。") }
        cells.append(value); return cells
    }
    public static func combined(source: String, target: String, enabled: Bool,
                                customSource: String, customTarget: String, custom: String) throws -> [String: String] {
        guard enabled else { return [:] }
        var result = preset(source: source, target: target)
        if customTarget == target && (source == customSource || source == "bailian-auto" || source == "auto" && ["zh", "en"].contains(customSource)) {
            result.merge(try parse(custom)) { _, custom in custom }
        }
        return result
    }
}
