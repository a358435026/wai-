import Foundation

public enum TradeTerminology {
    public static let examples = "额定功率\trated power\n交货期\tlead time\n最小起订量\tminimum order quantity"
    public static var builtInCount: Int { rows.count }

    // Common trading vocabulary based on ICC Incoterms 2020 and ITA export guides.
    // Order matters: for auto detection, retain core terms in every source language first.
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
        ["原产地证", "certificate of origin", "certificado de origem", "certificado de origen"],
        ["工厂交货", "EXW", "EXW", "EXW"],
        ["货交承运人", "FCA", "FCA", "FCA"],
        ["运费付至", "CPT", "CPT", "CPT"],
        ["运费和保险费付至", "CIP", "CIP", "CIP"],
        ["目的地交货", "DAP", "DAP", "DAP"],
        ["卸货地交货", "DPU", "DPU", "DPU"],
        ["完税后交货", "DDP", "DDP", "DDP"],
        ["船边交货", "FAS", "FAS", "FAS"],
        ["船上交货", "FOB", "FOB", "FOB"],
        ["成本加运费", "CFR", "CFR", "CFR"],
        ["成本保险费加运费", "CIF", "CIF", "CIF"],
        ["信用证", "letter of credit", "carta de crédito", "carta de crédito"],
        ["形式发票", "pro forma invoice", "fatura pro forma", "factura proforma"],
        ["采购订单", "purchase order", "ordem de compra", "orden de compra"],
        ["付款交单", "documents against payment", "documentos contra pagamento", "documentos contra pago"],
        ["承兑交单", "documents against acceptance", "documentos contra aceite", "documentos contra aceptación"],
        ["跟单托收", "documentary collection", "cobrança documentária", "cobranza documentaria"],
        ["赊账交易", "open account", "conta aberta", "cuenta abierta"],
        ["预付款", "advance payment", "pagamento antecipado", "pago anticipado"],
        ["尾款", "balance payment", "pagamento do saldo", "pago del saldo"],
        ["汇款", "remittance", "remessa bancária", "remesa bancaria"],
        ["空运单", "air waybill", "conhecimento aéreo", "carta de porte aéreo"],
        ["货运代理", "freight forwarder", "agente de carga", "agente de carga"],
        ["装运港", "port of shipment", "porto de embarque", "puerto de embarque"],
        ["报关单", "customs declaration", "declaração aduaneira", "declaración aduanera"],
        ["商品编码", "HS code", "código SH", "código SA"],
        ["关税", "customs duty", "direito aduaneiro", "derecho aduanero"],
        ["出口许可证", "export license", "licença de exportação", "licencia de exportación"],
        ["进口许可证", "import license", "licença de importação", "licencia de importación"],
        ["净重", "net weight", "peso líquido", "peso neto"],
        ["毛重", "gross weight", "peso bruto", "peso bruto"],
        ["外箱尺寸", "carton dimensions", "dimensões da caixa", "dimensiones de la caja"],
        ["运输保险", "cargo insurance", "seguro de carga", "seguro de carga"],
        ["装运日期", "shipment date", "data de embarque", "fecha de embarque"],
        ["预计到港时间", "estimated time of arrival", "hora prevista de chegada", "hora estimada de llegada"],
        ["单价", "unit price", "preço unitário", "precio unitario"],
        ["结算货币", "settlement currency", "moeda de liquidação", "moneda de liquidación"],
        ["价格有效期", "quotation validity", "validade da cotação", "validez de la cotización"],
        ["出货前检验", "pre-shipment inspection", "inspeção pré-embarque", "inspección previa al embarque"],
        ["产品合格证", "certificate of conformity", "certificado de conformidade", "certificado de conformidad"],
        ["售后服务", "after-sales service", "serviço pós-venda", "servicio posventa"],
        ["分批装运", "partial shipment", "embarque parcial", "embarque parcial"],
        ["转运", "transshipment", "transbordo", "transbordo"],
        ["托盘", "pallet", "palete", "palé"],
        ["集装箱", "shipping container", "contentor marítimo", "contenedor marítimo"],
        ["发货人", "shipper", "expedidor", "expedidor"],
        ["收货人", "consignee", "consignatário", "consignatario"],
        ["索赔", "claim", "reclamação", "reclamación"]
    ]
    private static let maximumSessionTerms = 100
    private static let codes = ["zh", "en", "pt", "es"]

    public static func preset(source: String, target: String) -> [String: String] {
        addPreset(to: [:], source: source, target: target)
    }

    private static func addPreset(to custom: [String: String], source: String, target: String) -> [String: String] {
        guard let output = codes.firstIndex(of: target) else { return custom }
        let inputs = source == "bailian-auto" ? codes : source == "auto" ? ["zh", "en"] : [source]
        let indices = inputs.compactMap { codes.firstIndex(of: $0) }.filter { $0 != output }
        var result = custom
        for row in rows {
            for index in indices {
                guard result.count < maximumSessionTerms else { return result }
                let key = row[index]
                if key != row[output], result[key] == nil { result[key] = row[output] }
            }
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
        var customTerms: [String: String] = [:]
        if customTarget == target && (source == customSource || source == "bailian-auto" || source == "auto" && ["zh", "en"].contains(customSource)) {
            customTerms = try parse(custom)
        }
        return addPreset(to: customTerms, source: source, target: target)
    }
}
