import 'dart:async';
import 'package:phone_state/phone_state.dart';

class CallService {
  StreamSubscription? _phoneStateSubscription;

  void startListening({
    required Function(Map<String, String>) onCallUpdate,
    required Function() onEnded,
  }) {
    print("ÇAĞRI SERVİSİ: Çağrı durumları dinlenmeye başlıyor (phone_state)...");

    _phoneStateSubscription?.cancel();

    _phoneStateSubscription = PhoneState.stream.listen((PhoneState state) async {
      print("ÇAĞRI SERVİSİ: Durum değişikliği algılandı -> ${state.status}, Numara: ${state.number}");

      switch (state.status) {
        case PhoneStateStatus.CALL_INCOMING:
          final incomingNumber = state.number;
          if (incomingNumber == null || incomingNumber.isEmpty) {
            print("ÇAĞRI SERVİSİ: Gelen arama var ancak numara alınamadı.");
            onCallUpdate({'name': 'Bilinmeyen', 'number': 'Numara Yok'});
            return;
          }

          onCallUpdate({
            'name': 'Bilinmeyen',
            'number': incomingNumber,
          });
          break;

        case PhoneStateStatus.CALL_ENDED:
        case PhoneStateStatus.NOTHING:
          onEnded();
          break;

        case PhoneStateStatus.CALL_STARTED:
          break;
      }
    });
  }

  void stopListening() {
    print("ÇAĞRI SERVİSİ: Dinleyici durduruluyor.");
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
  }
}
