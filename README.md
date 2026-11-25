# ����ͬ�� �� iPhone �����ͻ���

SwiftUI + AVAudioEngine + ��ɽ����ٷ� AST S2S�����趹�� App��Խ����ע�롣

## �װ湦��

- ���ġ�Ӣ�Ӣ������ġ���Ӣ�Զ����룻ʵʱԭ����������Ļ��
- 16 kHz / mono / PCM16 ¼�������ٷ������� 80 ms ��Ƶ��Ƭ���͡�
- �����ȷ�� SessionStarted �������¼�����յ� PCM16 �������ŶӲ��š�
- AVAudioEngine voice processing����˷羲������������������ʱ���ղ�����β�䡣
- ���ͻ�ѹ�����Ż�ѹ������������ӳ�ʱ���豸�жϴ�����
- API Key ���û����룬�����ڱ��� Keychain��������Դ�롢��־��UserDefaults��
- ��Ļ�ڵ�ǰ�Ự�ڴ��У�������¼���������̨�������ӣ�ǰ̨ͬ��������Ļ���ѡ�

## ��ͨ����

�ڻ�ɽ���濪ͨ������ͬ�����롹����ȷ�϶�ȡ�����Ȩ�ޡ�
�� App ����������д�÷�����õ� API Key������Ŀ�ĵع̶�Ϊ�ٷ��˵㣺

`wss://openspeech.bytedance.com/api/v4/ast/v2/translate`

��Ȩ��`X-Api-Key`����Դ��`volc.service_type.10053`��
���񰴹ٷ�����Ʒѣ��Ͷ��� App ����Ѷ���޹ء������ڼ�Ự�������С�
δָ�� speaker_id��ʹ�÷���Ĭ�ϵ�ʵʱ����˵������ɫ��ʵ����ɫ��������Ȩ����ʵ�⡣

## ���ػ� GitHub ����

��Ҫ Mac + Xcode��֧�� iOS 17+ SDK���� XcodeGen��

```sh
swift test
brew install xcodegen # δ��װʱ
xcodegen generate
open Tongchuan.xcodeproj
```

GitHub Actions `.github/workflows/ios.yml` �� macOS ��ִ�к��Ĳ��ԡ����Ŀ������ģ�����������ԡ�
���� `Tongchuan-unsigned.ipa` **δǩ��������ֱ�Ӱ�װ**�������û�ʹ���Լ���ǩ����ʽ��װ��
Ҳ���� Xcode ѡ���Լ��� Apple Team ���������ǩ�����С�TestFlight ��Ҫ�������˺źͷ������á�
δ��֤�顢Apple ID �� API Key ���� Actions��

## ��������嵥�������ɹ����������

1. ������Ч Key����ͨ��˷磺˵���ģ���ʾӢ�Ĳ�����Ӣ������������ͬ�����ԡ�
2. ��ų��� 5 ���ӣ�ȷ���������ᱻ����ʰȡ���������жϡ��ӳ�û�г�����ѹ��
3. ����/���߶������л�������γ������������жϡ������̨��
4. ������ʼ/ֹͣ��������ȡ����ʧЧ Key�����㡢������ָ���
5. ֹͣ���ٲɼ������һ����Ļ��������β��Key ����������־����ͨƫ�������С�

## ʵ��������

`Sources/Core/ASTProtocol.swift` �����ݹٷ� `.proto` �ֶκ�ʵ�ֵľ��� protobuf wire codec��
��ʹ�� DeepSeek ������� SAMI/voicegenie ˽��Э�顣����δ֪ varint�����Ⱥ� fixed32/64 �ֶΡ�
`Protocol/` �����ٷ���Ϣ������Ϊ���գ�`Tests/CoreTests/Fixtures/` ���Թٷ� Python �����ɵĺϳ����ݡ�

��Ӧ��δ���ö��������ơ�UI ��Դ��˽�� token ���¼̬��ԭ�����������⽻����
�װ治�ṩ��̨����¼�������� App/�绰���ڲ���Ƶ����Ҳδ�����Ѿ�ͨ����ʵ API ��������ԡ�
������������ʵ�����ӳٱ������û��豸����Ƶ·�ɺ�ʵ�����������ա�

## �ٷ�����

- https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh
- https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation-1?lang=zh
- https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)

���Ƕ����������ÿͻ��ˣ��붹�� App ��������ϵ��
