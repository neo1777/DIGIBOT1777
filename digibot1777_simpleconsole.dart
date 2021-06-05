import 'dart:async';
import 'package:digibot_copy/digibot_copy.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main(List<String> arguments) async {
  load();
  var dgtx = WebSocketProvide();
  dgtx.time_start = DateTime.now();
  //print(dgtx.funzioneRound('${env['Cross']}-PERP', 1235));
  //if (await dgtx.funzione_Orario('${env['Cross']}-PERP')) {
  var str = await dgtx.getWsMaster(
      uri: env['Url'],
      simb: env['Cross'],
      authcode: env['Token'],
      params: [
        '${env['Cross']}-PERP@index',
        '${env['Cross']}-PERP@trades',
        '${env['Cross']}-PERP@ticker',
        '${env['Cross']}-PERP@kline_1min',
        '${env['Cross']}-PERP@orderbook_1'
      ]);
  //} else {
  //  print('Attesa orario...');
  //}

  if (env['print_info'] == 'true') {
    var time = Duration(seconds: int.parse(env['time_print_seconds']));
    Timer.periodic(time, (timer) {
      var now = DateTime.now();
      Duration difference = now.difference(dgtx.time_start);
      print('');
      print(
          '${now.day}/${now.month}/${now.year} - ${now.hour}:${now.minute} Run time days/hours/minutes: ${difference.inDays}/${difference.inHours}/${difference.inMinutes}');
      print('Balance start: ${dgtx.balance_Start.toStringAsFixed(2)}');
      print('Profit balance: ${dgtx.diff_balance.toStringAsFixed(2)}');
      print('MAX Profit: ${dgtx.balanceMax.toStringAsFixed(2)}');
      print('MIN Profit: ${dgtx.balanceMin.toStringAsFixed(2)}');
      print(
          'Spread average: ${dgtx.mean.toStringAsFixed(3)} limit: ${dgtx.limitSpread}');
      print(
          'Media exp spread: ${dgtx.mean_exponential.toStringAsFixed(3)} - factor 0.1');
      print(
          'Speed average: ${dgtx.mean_speed_ladder.toStringAsFixed(3)} limit: ${dgtx.limitSpeed}');
      print(
          'Media exp speed: ${dgtx.mean_speed_ladder_exponential.toStringAsFixed(3)} - factor 0.1');
      if (env['DeltaOrdiniVariabile'] != '0') {
        print('Delta ordini: ${dgtx.funzioneDeltaOrdini()}');
      }
      //print('stopMetod: ${dgtx.stopMetod}');
      print('');
      print('PARAMETRI');
      print('-------------');
      print('Cross: ${env['Cross']}');
      print('Size: ${env['Size']}');
      if (env['DeltaOrdiniVariabile'] != '0') {
        print('DeltaOrdiniVariabile: ${env['DeltaOrdiniVariabile']}');
      } else {
        print('DeltaOrdini: ${env['DeltaOrdini']}');
      }
      if (env['AddLimit'] != '0') {
        print('AddLimit: ${env['AddLimit']}');
      }
      print('N_ord_start: ${env['N_ord_start']}');
      print('OrdersLimit: ${env['OrdersLimit']}');
      if (env['Alternate'] != 'false') {
        print('Alternate: ${env['Alternate']}');
      }

      if (env['stopBalance'] != '0') {
        print('stopBalance: ${env['stopBalance']}');
        print('metodoBalanceS: ${env['metodoBalanceS']}');
        print('DelayStop: ${env['DelayStop']}');
        print('SogliaCloseSoft: ${env['SogliaCloseSoft']}');
      }
      if (env['takeBalance'] != '0') {
        print('takeBalance: ${env['takeBalance']}');
        print('metodoBalanceT: ${env['metodoBalanceT']}');
        print('DelayTake: ${env['DelayTake']}');
        print('SogliaCloseSoft: ${env['SogliaCloseSoft']}');
      }

      if (env['stopUPnL'] != '0') {
        print('stopUPnL: ${env['stopUPnL']}');
        print('metodoUPnLS: ${env['metodoUPnLS']}');
        print('DelayStop: ${env['DelayStop']}');
        print('SogliaCloseSoft: ${env['SogliaCloseSoft']}');
      }
      if (env['takeUPnL'] != '0') {
        print('takeUPnL: ${env['takeUPnL']}');
        print('metodoUPnLT: ${env['metodoUPnLT']}');
        print('DelayTake: ${env['DelayTake']}');
        print('SogliaCloseSoft: ${env['SogliaCloseSoft']}');
      }

      if (env['stopOpen_Contracts'] != '0') {
        print('stopOpen_Contracts: ${env['stopOpen_Contracts']}');
        print('metodoOpen_Contracts: ${env['metodoOpen_Contracts']}');
      }

      if (env['stopOpen_Spread'] != '0') {
        print('stopOpen_Spread: ${env['stopOpen_Spread']}');
        print('deltaSpread: ${env['deltaSpread']}');
        print('rangeMean: ${env['rangeMean']}');
        print('close_instantly: ${env['close_instantly']}');
      }
      print('---');
    });
  }
}
//DGTXBTCUSD
//3,766
//DGTXBTCUSD
//DeltaOrdini
/*
  var now = DateTime.now();
  print('${now.hour}:${now.minute}:${now.second}');


  var currDt = DateTime.now().day;
  //var time = DateTime.parse('${} 13:27:00');
  //print('time: ${currDt.isBefore(time)}'); // 4
  print('time: ${currDt}'); // 4
  print( Date.yMMMd().format(DateTime.now()));


  var currDt = DateTime.now();
  print(currDt.year); // 4
  print(currDt.weekday); // 4
  print(currDt.month); // 4
  print(currDt.day); // 2
  print(currDt.hour); // 15
  print(currDt.minute); // 21
  print(currDt.second); // 49


  print(DateTime.now());
  var time = Duration(seconds: int.parse(env['Delay']));
  await Future.delayed(time);
  print(DateTime.now()); // This will be printed 10 seconds later.

*/
