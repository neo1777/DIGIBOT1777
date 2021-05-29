import 'dart:async';
import 'package:digibot_copy/digibot_copy.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main(List<String> arguments) async {
  load();
  var dgtx = WebSocketProvide();
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
          '${now.day}/${now.month}/${now.year} - ${now.hour}:${now.minute} Run time hours: ${difference.inHours}');
      print('Profit balance: ${dgtx.diff_balance}');
      print('Spread average: ${dgtx.mean} limit: ${dgtx.limitSpread}');
      print('Media exp factor 0.1: ${dgtx.mean_exponential}');
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
