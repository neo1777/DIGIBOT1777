import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:random_string/random_string.dart';
import 'package:web_socket_channel/io.dart';
import 'package:meta/meta.dart';
import 'package:dotenv/dotenv.dart';

class Ws_Util {
  static int req_id = 0;

  int get next_req_id => req_id++;
  String get generate_id => randomAlphaNumeric(16);
  dynamic round_price(price, symbol) =>
      (price / tickSize(symbol)).round() * tickSize(symbol);

  double tickSize(symbol) {
    if (symbol == 'BTCUSD-PERP') {
      return 5;
    }
    if (symbol == 'ETHUSD-PERP') {
      return 1;
    }
    if (symbol == 'XRPUSD-PERP') {
      return 1;
    }
    if (symbol == 'BTCUSD1-PERP') {
      return 1;
    }
    if (symbol == 'XAUUSD-PERP') {
      return 0.5;
    }
    if (symbol == 'AMZNUSD-PERP') {
      return 1;
    }

    return 1;
  }
}

class WebSocketProvide {
  IOWebSocketChannel channelMaster;
  Stream streamBroadcast;
  Ws_Util ws_util = Ws_Util();
  bool trading_available = false;
  Map open_contracts = {};
  Map active_cond_orders = {};
  Map active_orders = {};
  Set active_orders_ListPx = {};
  Set active_orders_ListPx_controll = {};
  double ladderPx = 0.0;
  Set ladderPx_List_UP = {};
  Set ladderPx_List_DW = {};
  int n_order = int.parse(env['N_ord_start']);
  bool first_control = true;
  double balance = 0.0;
  double balance_Start = 0.0;
  double pnl = 0.0;
  int open_contracts_start = 0;

  double upnl = 0.0;
  int leverage = 0;
  double upnl_Start = 0.0;
  bool startBotTrading = true;
  String stop_time = '';
  var contract_value = 0.0;
  var positionType_start = '';
  var data_trade;
  bool attiva_BUY = true;
  bool attiva_SELL = true;
  var amount_B = double.parse(env['Size']);
  var amount_S = double.parse(env['Size']);
  bool cancel_B = true;
  bool cancel_S = true;

  Stream getWsMaster({String uri, String simb, String authcode, List params}) {
    channelMaster = IOWebSocketChannel.connect(uri);
    var data_auth = {
      'id': Ws_Util().next_req_id,
      'method': 'auth',
      'params': {'type': 'token', 'value': authcode}
    };
    var data = {
      'id': Ws_Util().next_req_id,
      'method': 'subscribe',
      'params': params
    };
    streamBroadcast = channelMaster.stream.asBroadcastStream();
    channelMaster.sink.add(json.encode(data_auth));
    channelMaster.sink.add(json.encode(data));
    listenAll(streamBroadcast, simb, true)
      ..onDone(() async {
        print('onDone received');
        await listenAll(streamBroadcast, simb, true);
      })
      ..onError((e) {
        print('onError received ${e}');
        listenAll(streamBroadcast, simb, true);
      });
    return streamBroadcast;
  }

  StreamSubscription listenAll(Stream str, simb, bool permanent) {
    return str.listen((msg) async {
      if (msg.toString() != 'ping') {
        if (env['print_all'] == 'true') {
          print(msg);
        }
        Map response = json.decode(msg.toString());
        if (response.containsKey('status')) {
          if (response['status'] == 'error' && env['print_error'] == 'true') {
            print('ERROR received: ${response}');
          }
        }
        if (response.containsKey('ch')) {
          await handle_exchange_message(channelMaster, simb, response);
        } else {
          //print('received: ${response}');
        }
      } else {
        if (permanent) {
          channelMaster.sink.add('pong');
        }
      }
    });
  }

  Future handle_exchange_message(ws, simb, Map resp) async {
    var msg = resp['ch'].toString();
    if (msg.startsWith('orderbook')) {
      msg = 'orderbook';
    }
    if (msg.startsWith('kline')) {
      msg = 'kline';
    }
    try {
      switch (msg) {
        case 'index':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_index_price(ws, resp);');
            }
          }
          break;
        case 'orderbook':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_orderbook(ws, resp);');
            }
          }
          break;
        case 'trades':
          {
            if (trading_available) {
              if (resp['data']['symbol'] == '${simb}-PERP') {
                await handle_trades(ws, resp, simb);
                if (env['print_handle'] == 'true') {
                  print('await handle_order_status(ws, resp);');
                  print('trades_SYMBOL OK: ${resp['data']['symbol']}');
                }
              } else {
                if (env['print_handle'] == 'true') {
                  print('trades_SYMBOL NOT OK: ${resp['data']['symbol']}');
                }
              }
            }

            if (env['print_handle'] == 'true') {
              print('await handle_trades(ws, simb, resp);');
            }
          }
          break;
        case 'kline':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_kline(ws, resp);');
            }
          }
          break;
        case 'ticker':
          if (resp['data']['symbol'] == '${simb}-PERP') {
            await handle_ticker(ws, resp);
            if (env['print_handle'] == 'true') {
              print('await handle_ticker(ws, resp);');
              print('handle_ticker_SYMBOL OK: ${resp['data']['symbol']}');
            }
          } else {
            if (env['print_handle'] == 'true') {
              print('handle_ticker_SYMBOL NOT OK: ${resp['data']['symbol']}');
            }
          }

          break;
        case 'orderStatus':
          {
            if (resp['data']['symbol'] == '${simb}-PERP') {
              await handle_order_status(ws, resp);
              if (env['print_handle'] == 'true') {
                print('await handle_order_status(ws, resp);');
                print('orderStatus_SYMBOL OK: ${resp['data']['symbol']}');
              }
            } else {
              if (env['print_handle_order'] == 'true') {
                print('orderStatus_SYMBOL NOT OK: ${resp['data']['symbol']}');
              }
            }
          }
          break;
        case 'orderFilled':
          {
            if (resp['data']['symbol'] == '${simb}-PERP') {
              await handle_order_filled(ws, resp);
              if (env['print_handle'] == 'true') {
                print('await handle_order_filled(ws, resp);');
                print('orderFilled_SYMBOL OK: ${resp['data']['symbol']}');
              }
            } else {
              if (env['print_handle'] == 'true') {
                print('orderFilled_SYMBOL NOT OK: ${resp['data']['symbol']}');
              }
            }
          }
          break;
        case 'orderCancelled':
          {
            if (resp['data']['symbol'] == '${simb}-PERP') {
              await handle_order_cancelled(ws, resp);
              if (env['print_handle'] == 'true') {
                print('await handle_order_cancelled(ws, resp);');
                print('orderCancelled_SYMBOL OK: ${resp['data']['symbol']}');
              }
            } else {
              if (env['print_handle'] == 'true') {
                print(
                    'orderCancelled_SYMBOL NOT OK: ${resp['data']['symbol']}');
              }
            }
          }
          break;
        case 'traderStatus':
          {
            if (resp['data']['symbol'] == '${simb}-PERP') {
              await handle_trader_status(ws, resp, simb);
              if (env['print_handle'] == 'true') {
                print('await handle_trader_status(ws, resp);');
                print('traderStatus_SYMBOL OK: ${resp['data']['symbol']}');
                print('handle_trader_status: ${resp}');
              }
            } else {
              if (env['print_handle'] == 'true') {
                print('traderStatus_SYMBOL NOT OK: ${resp['data']['symbol']}');
              }
            }
          }
          break;
        case 'error':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_error(ws, resp);');
            }
          }
          break;
        case 'contractClosed':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_contract_closed(ws, resp);');
            }
          }
          break;
        case 'condOrderStatus':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_conditional_order_status(ws, resp);');
            }
          }
          break;
        case 'leverage':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_leverage(ws, resp);');
            }
          }
          break;
        case 'funding':
          {
            if (env['print_handle'] == 'true') {
              print('await handle_funding(ws, resp);');
            }
          }
          break;
        case 'tradingStatus':
          {
            await handle_trading_status(ws, resp);
            if (env['print_handle'] == 'true') {
              print('await handle_trading_status(ws, resp);');
            }
            //print('${resp}');
          }
          break;

        default:
          {
            if (env['print_handle'] == 'true') {
              print('unhandled message: ${resp.toString()}');
            }
          }
          break;
      }
    } catch (e) {
      if (env['print_handle'] == 'true') {
        print('WARNING! Exception: ${e}, status: $msg');
      }
    }
  }

//verifica permessi trading
  Future handle_trading_status(ws, msg) async {
    //print('handle_trading_status= ${msg}');
    var data = msg['data'];
    if (data['available'] == true) {
      trading_available = true;
      print('Time: ${DateTime.now()}');
      print('trading: AVAILABLE');
    } else {
      trading_available = false;
      print('Time: ${DateTime.now()}');
      print('trading: NOT AVAILABLE');
    }
  }

//prezzo ladder
  Future handle_trades(ws, msg, simb) async {
    //print('ladderPx_ALL: ${msg['data']['trades']}');
    for (var item in msg['data']['trades']) {
      ladderPx = item['px'].toDouble();
      //print('ladderPx_${msg['data']['trades'].indexOf(item)} = ${item['px']}');
    }
    //print('LAST ladderPx= ${ladderPx}');
    getTraderStatus(channel: channelMaster, symbol: '${simb}-PERP');

    /*
    if (ladderPx != msg['data']['trades'][0]['px']) {
      for (var item in msg['data']['trades']) {
        ladderPx = item['px'].toDouble();
      }
      //print('ladderPx= ${ladderPx}');
      getTraderStatus(channel: channelMaster, symbol: '${simb}-PERP');
    }

    */
  }

  //richiesta stato
  void getTraderStatus(
      {@required IOWebSocketChannel channel, @required String symbol}) {
    var params = {'symbol': symbol};
    var req = {
      'id': ws_util.next_req_id,
      'method': 'getTraderStatus',
      'params': params
    };
    channel.sink.add(json.encode(req));
  }

  //risposta stato
  Future handle_trader_status(ws, msg, simb) async {
    //print(msg['data']);
    var data = msg['data'];
    data_trade = data;
    var trader_balance = data['traderBalance'].toDouble();
    var trader_leverage = data['leverage'];
    leverage = trader_leverage;
    var trader_upnl = data['upnl'].toDouble();
    upnl = trader_upnl.toDouble();
    var trader_pnl = data['pnl'].toDouble();
    var orderMargin = data['orderMargin'];
    var positionMargin = data['positionMargin'];
    var positionContracts = data['positionContracts'];
    var positionVolume = data['positionVolume'];
    var positionLiquidationVolume = data['positionLiquidationVolume'];
    var positionBankruptcyVolume = data['positionBankruptcyVolume'];
    positionType_start = data['positionType'];
    funzioneControlloOrdini(data);
    /*
    print('positionVolume: ${positionVolume}');
    print('positionLiquidationVolume: ${positionLiquidationVolume}');
    print('positionBankruptcyVolume: ${positionBankruptcyVolume}');
    print('positionType: ${positionType}');
    print('traderBalance: ${trader_balance}');
    print('orderMargin: ${orderMargin}');
    print('positionMargin: ${positionMargin}');
    print('total margin: ${positionMargin + orderMargin}');

    /*print('Datetime: ${DateTime.now()}');
    print('positionType: ${positionType}');
    print('orderMargin: ${orderMargin}');
    print('positionMargin: ${positionMargin}');
    print('positionContracts: ${positionContracts}');
    print('positionVolume: ${positionVolume}');
    print('positionLiquidationVolume: ${positionLiquidationVolume}');
    print('positionBankruptcyVolume: ${positionBankruptcyVolume}');
    print('contracts: ${data['activeOrders'].length}');
    */
    //print(
    //'ABal: ${trader_balance - ((data['activeOrders'].length + positionContracts) * (orderMargin / 2))}');*/
    //print('ABal: ${positionMargin + orderMargin}');
    //print('ABal: ${trader_balance - positionMargin}');
    if (balance != trader_balance) {
      balance = trader_balance;
      if (balance_Start == 0.0) {
        balance_Start = balance;
      }
      var diff_balance = balance - balance_Start;
      funzione_Balance(diff_balance, data['symbol']);
      if (env['print_info_bal'] == 'true') {
        print('trader diff_balance: ${diff_balance}');
      }
    }

    if (upnl_Start != trader_upnl) {
      upnl_Start = trader_upnl;
      funzione_UPnL(trader_upnl, data['symbol']);
      if (env['print_info_upnl'] == 'true') {
        print('trader UPnL: ${trader_upnl}');
      }
    }

    if (open_contracts_start != positionContracts) {
      open_contracts_start = positionContracts;
      funzione_open_contracts(positionContracts, data['symbol']);
      if (env['print_info_ctr'] == 'true') {
        print('trader Open_contracts: ${open_contracts_start}');
      }
    }

    if (data.containsKey('positionType')) {
      var total_contracts = data['positionContracts'];
      var pos_type = data['positionType'];
      //print('trader position: ${pos_type}@${total_contracts}');
    }
    open_contracts = {};
    if (data.containsKey('contracts')) {
      List contractlist = data['contracts'];
      contractlist.forEach((c) {
        var contract_id = c['contractId'];
        open_contracts[contract_id] = c;
      });
      //print('open contracts: ${open_contracts}');
    }

    var symbol = data['symbol'];
    active_orders = {};
    active_orders_ListPx = {};
    if (data.containsKey('activeOrders')) {
      List orderlist = data['activeOrders'];

      orderlist.forEach((o) {
        var cl_ord_id = o['clOrdId'];
        var ord_type = o['orderType'];
        var ord_side = o['orderSide'];
        var ord_tif = o['timeInForce'];
        var px;
        if (o.containsKey('px')) {
          px = o['px'];
          funzione_Max_Orders(data['symbol'], o['px']);
        } else {
          px = 0.0;
        }
        var qty = o['qty'];

        var res = {
          'symbol': symbol,
          'orderType': ord_type,
          'side': ord_side,
          'ti': ord_tif,
          'px': px,
          'qty': qty
        };
        if (funzioneRound(simb, px.toDouble())) {
          active_orders['$cl_ord_id'] = res;
          active_orders_ListPx.add(px);
        }
      });
      //print('active_orders handle_trader_status: $active_orders');
    }

    if (data.containsKey('conditionalOrders')) {
      List cond_orderlist = data['conditionalOrders'];
      cond_orderlist.forEach((co) {
        var action_id = co['actionId'];
        active_cond_orders[action_id] = co;
      });
    }
    //print('active conditional orders: $active_cond_orders');

    await funzione_Orario(data['symbol']);
    ladderPx_List_DW = {};
    ladderPx_List_UP = {};
    funzioneOrdini(simb);
  }

  Future<int> funzioneLimitType(
      List activeorder, String positionType, int positionContracts) async {
    var out = 0;
    var out_S = 0;
    var out_B = 0;
    //print(positionType);
    //print(contract_value);
    if (positionType == 'SHORT') {
      out_S = 0; //-positionContracts; //0;
      out_B = -positionContracts; // 0;
    }
    if (positionType == 'LONG') {
      out_S = -positionContracts; // 0;
      out_B = 0; //-positionContracts; //0;
    }

    for (var item in activeorder) {
      if (item['orderSide'] == 'BUY') {
        out_B++;
      } else if (item['orderSide'] == 'SELL') {
        out_S++;
      }
    }

    if (out_B >= out_S) {
      out = out_B;
    }
    if (out_S > out_B) {
      out = out_S;
    }
    /*
    if (positionType == 'SHORT') {
      out_B = out_B - positionContracts;
    } else if (positionType == 'LONG') {
      out_S = out_S - positionContracts;
    }
    if (tp == 'BUY') {
      out = out_B;
    } else if (tp == 'SELL') {
      out = out_S;
    }
    out = out_S - out_B;*/
    //out = out - positionContracts;
    return out;
  }

  Future handle_order_status(ws, msg) async {
    var data = msg['data'];
    var cl_ord_id = data['clOrdId'];
    var status = data['orderStatus'];
    if (status == 'ACCEPTED') {
      var symbol = data['symbol'];
      var ord_type = data['orderType'];
      var ord_side = data['orderSide'];
      var ord_tif = data['timeInForce'];
      var px = data['px'];
      var qty = data['qty'];

      if (ord_type == 'LIMIT') {
        //print('order ${cl_ord_id} has been ACCEPTED: ${msg}');
        //print('LIMIT open_contracts: ${active_orders_ListPx.length}');
        //print('LIMIT active_orders: ${active_orders.length}');
        if (qty > amount_B && data['orderSide'] == 'LONG') {
          if (env['print_cancel'] == 'true') {
            print(
                'Cancell order handle_order_status != amount_B - side: ${data['orderSide']} qty: ${data['qty']} px: ${data['px']}');
          }

          await cancel_limit_order_all(
              channel: channelMaster,
              symbol: symbol,
              px: data['px'],
              side: 'SELL');
        }
        if (qty > amount_S && data['orderSide'] == 'SHORT') {
          if (env['print_cancel'] == 'true') {
            print(
                'Cancell order handle_order_status != amount_S - side: ${data['orderSide']} qty: ${data['qty']} px: ${data['px']}');
          }

          await cancel_limit_order_all(
              channel: channelMaster,
              symbol: symbol,
              px: data['px'],
              side: 'BUY');
        }
        /*active_orders.forEach((key, value) {
          if (px == value['px']) {
            //print('LIMIT px: ${value['px']}');
            cancel_limit_order_all(
                channel: channelMaster, symbol: symbol, px: px, side: '');
          }
        });*/
      }

      var res = {
        'symbol': symbol,
        'orderType': ord_type,
        'side': ord_side,
        'ti': ord_tif,
        'px': px,
        'qty': qty
      };
      //active_orders['$cl_ord_id'] = res;
    } else if (status == 'REJECTED' && data.containsKey('errCode')) {
      var error_code = data['errCode'];
      if (env['print_error'] == 'true') {
        print(
            'order ${cl_ord_id} has been REJECTED with error code: ${error_code}');
        if (error_code == 27) {
          print('REJECTED open_contracts: ${active_orders_ListPx.length}');
          print('REJECTED active_orders: ${active_orders.length}');
          print('data position close: ${data_trade['positionType']}');

          //await funzione_closeAll_Limit(data['symbol']);
        }
      }

      //await contracts_limit_list.remove(data['px']);
      //cancel_limit_order_all(
      //channel: channelMaster, symbol: data['symbol'], px: 0, side: 'SELL');
    }
    return 0;
  }

  Future handle_order_filled(ws, msg) async {
    var data = msg['data'];
    var filled_ord_id = data['clOrdId'];
    var order_status = data['orderStatus'];

    // if (order_status == 'FILLED') {
    //   //print('order ${filled_ord_id} has been FILLED');
    // } else if (order_status == 'PARTIALLY_FILLED') {
    //   //print('order ${filled_ord_id} has been PARTIALLY FILLED');
    // } else {
    //   //print('order ${filled_ord_id} has status: ${order_status}');
    // }
    //print(msg['data']['px']);
    if (active_orders.containsKey('$filled_ord_id')) {
      if (funzioneRound(msg['data']['symbol'], msg['data']['px'].toDouble())) {
        active_orders.remove(filled_ord_id);
        active_orders_ListPx.remove(msg['data']['px']);
      }
    }

    //print('active orders handle_order_filled: ${active_orders}');
  }

/*
funzioneOrdini(simb) async {
    var sideX = '';
    var numero = n_order;
    if (env['Alternate'] == 'true') {
      numero = n_order * 2;
    }
    while (numero >= -n_order) {
      if (numero < -int.parse(env['DeltaOrdini']) ||
          numero > int.parse(env['DeltaOrdini'])) {
        if (funzioneRound(simb, ladderPx.toDouble())) {
          if (a_Balance > contract_value * 2) {
            ladderPx_List
                .add(ladderPx + (numero * ws_util.tickSize('${simb}-PERP')));
          } else {
            if (positionType_start == 'LONG' &&
                numero > int.parse(env['DeltaOrdini'])) {
              ladderPx_List
                  .add(ladderPx + (numero * ws_util.tickSize('${simb}-PERP')));
            }
            if (positionType_start == 'SHORT' &&
                numero < -int.parse(env['DeltaOrdini'])) {
              ladderPx_List
                  .add(ladderPx + (numero * ws_util.tickSize('${simb}-PERP')));
            }
          }
        }
      }
      numero--;
    }

    //print(ladderPx_List);

    for (var item in ladderPx_List) {
      if (item < ladderPx) {
        sideX = 'BUY';
      }
      if (item > ladderPx) {
        sideX = 'SELL';
      }
      if (!active_orders_ListPx.contains(item)) {
        var funzione_orario = await funzione_Orario('${simb}-PERP');
        if (startBotTrading && funzione_orario) {
          if (funzioneRound(simb, item.toDouble())) {
            place_limit_order(
                symbol: '${simb}-PERP',
                side: sideX,
                price: item,
                amount: double.parse(env['Size']),
                tif: 'GTC');
          }
        }

        //print('open order $item');
      }
    }
  }
*/

  funzioneOrdini(simb) async {
    var sideX = '';
    var numero = n_order;
    if (env['Alternate'] == 'true') {
      numero = n_order * 2;
    }
    if (int.parse(env['AddLimit']) > 0) {
      //print('data_trade[positionType]: ${data_trade['positionType']}');
      if (data_trade['positionType'] == null) {
        //attiva_SELL = false;
        //attiva_BUY = true;
        amount_B = double.parse(env['Size']);
        amount_S = double.parse(env['Size']);
        cancel_S = true;
        cancel_B = true;
      }
      if (data_trade['positionType'] == 'SHORT') {
        //attiva_SELL = false;
        //attiva_BUY = true;
        amount_B = double.parse(env['Size']) + int.parse(env['AddLimit']);
        amount_S = double.parse(env['Size']);
        if (!cancel_B) {
        } else {
          await cancel_limit_order_all(
              channel: channelMaster,
              symbol: data_trade['symbol'],
              px: 0,
              side: 'BUY');
          cancel_B = false;
          cancel_S = true;
        }
      }
      if (data_trade['positionType'] == 'LONG') {
        //attiva_BUY = false;
        //attiva_SELL = true;
        amount_S = double.parse(env['Size']) + int.parse(env['AddLimit']);
        amount_B = double.parse(env['Size']);
        if (!cancel_S) {
        } else {
          await cancel_limit_order_all(
              channel: channelMaster,
              symbol: data_trade['symbol'],
              px: 0,
              side: 'SELL');
          cancel_S = false;
          cancel_B = true;
        }
      }
    }
    var lmt_down = int.parse(env['DeltaOrdini']);
    var ladderPxMax_Near =
        ladderPx + (lmt_down * ws_util.tickSize('${simb}-PERP'));
    var ladderPxMin_Near =
        ladderPx - (lmt_down * ws_util.tickSize('${simb}-PERP'));

    if (env['Liquidity'] == 'true' &&
        ladderPx_List_UP.isNotEmpty &&
        ladderPx_List_DW.isNotEmpty) {
      if (ladderPx_List_DW.last <= ladderPxMax_Near) {
        // print(
        //     'Cancell order liquidity - side: ${u['orderSide']} id: ${u['clOrdId']} px: ${u['px']}');
        await cancel_limit_order_all(
            channel: channelMaster,
            symbol: data_trade['symbol'],
            px: ladderPx_List_DW.last,
            side: '');
        //list.add(items['activeOrders'].first['px']);
      }
      if (ladderPx_List_UP.last >= ladderPxMin_Near) {
        // print(
        //     'Cancell order liquidity - side: ${u['orderSide']} id: ${u['clOrdId']} px: ${u['px']}');
        await cancel_limit_order_all(
            channel: channelMaster,
            symbol: data_trade['symbol'],
            px: ladderPx_List_UP.last,
            side: '');
        //list.add(items['activeOrders'].first['px']);
      }
    }

    for (var i = 0; i < numero; i++) {
      if (i > int.parse(env['DeltaOrdini'])) {
        var priceToadd_S = ladderPx + (i * ws_util.tickSize('${simb}-PERP'));

        if (funzioneRound(simb, priceToadd_S) && attiva_SELL) {
          ladderPx_List_UP.add(priceToadd_S);
          //print('Ladder DW: ${priceToadd_S} ladder: ${ladderPx}');
          active_orders_ListPx_controll.add(priceToadd_S);
        }
      }
    }
    for (var i = 0; i > -numero; i--) {
      if (i < -int.parse(env['DeltaOrdini'])) {
        var priceToadd_B = ladderPx + (i * ws_util.tickSize('${simb}-PERP'));
        if (funzioneRound(simb, priceToadd_B) && attiva_BUY) {
          ladderPx_List_DW.add(priceToadd_B);
          //print('Ladder UP: ${priceToadd_B} ladder: ${ladderPx}');
          active_orders_ListPx_controll.add(priceToadd_B);
        }
      }
    }

    //print(ladderPx_List);

    for (var item in ladderPx_List_DW) {
      sideX = 'BUY';
      if (!active_orders_ListPx.contains(item)) {
        var funzione_orario = await funzione_Orario('${simb}-PERP');
        if (startBotTrading && funzione_orario) {
          if (funzioneRound(simb, item.toDouble()) && attiva_BUY) {
            place_limit_order(
                symbol: '${simb}-PERP',
                side: sideX,
                price: item,
                amount: amount_B,
                tif: 'GTC');
          }
        }

        //print('open order $item');
      }
    }
    for (var item in ladderPx_List_UP) {
      sideX = 'SELL';
      if (!active_orders_ListPx.contains(item)) {
        var funzione_orario = await funzione_Orario('${simb}-PERP');
        if (startBotTrading && funzione_orario) {
          if (funzioneRound(simb, item.toDouble()) && attiva_SELL) {
            place_limit_order(
                symbol: '${simb}-PERP',
                side: sideX,
                price: item,
                amount: amount_S,
                tif: 'GTC');
          }
        }

        //print('open order $item');
      }
    }
  }

  void place_limit_order(
      {@required String symbol,
      @required String side,
      @required double price,
      @required double amount,
      @required String tif}) {
    var params = {
      'symbol': symbol,
      'clOrdId': ws_util.generate_id,
      'ordType': 'LIMIT',
      'timeInForce': tif,
      'side': side,
      'px': ws_util.round_price(price, symbol),
      'qty': amount
    };
    var req = {
      'id': ws_util.next_req_id,
      'method': 'placeOrder',
      'params': params
    };
    if (env['print_orders'] == 'true') {
      print('order open: ${params}');
    }
    channelMaster.sink.add(json.encode(req));
  }

  void cancel_limit_order(
      {@required IOWebSocketChannel channel,
      @required String symbol,
      @required String clOrdId}) {
    var params = {
      'symbol': symbol,
      'clOrdId': clOrdId, //ws_util.generate_id,
    };
    var req = {
      'id': ws_util.next_req_id,
      'method': 'cancelOrder',
      'params': params
    };
    print('cancel_limit_order: $clOrdId - $symbol');

    channel.sink.add(json.encode(req));
  }

  Future<void> cancel_limit_order_all(
      {@required IOWebSocketChannel channel,
      @required String symbol,
      @required num px,
      @required String side}) async {
    var params = {
      'symbol': symbol,
      'px': px,
      'side': side,
    };
    var req = {
      'id': ws_util.next_req_id,
      'method': 'cancelAllOrders',
      'params': params
    };
    var time = Duration(milliseconds: 1000);
    await Future.delayed(time);
    channel.sink.add(json.encode(req));
  }

  Future close_position(
      {@required IOWebSocketChannel channel,
      @required String symbol,
      @required num px,
      @required String ord_type}) async {
    if (ord_type == 'LIMIT' && px == null) {
      print('price must be specified for LIMIT order');
      return null;
    }
    var params = {'symbol': symbol, 'ordType': ord_type, 'px': px};

    var req = {
      'id': ws_util.next_req_id,
      'method': 'closePosition',
      'params': params
    };
    //print('closing position');
    channel.sink.add(json.encode(req));
  }

  bool funzione_Max_Orders(symbol, price) {
    var lmt = int.parse(env['OrdersLimit']);
    if (env['Alternate'] == 'true') {
      lmt = int.parse(env['OrdersLimit']) * 2;
    }

    var ladderPxMaxUp = ladderPx + (lmt * ws_util.tickSize(symbol));
    var ladderPxMinDw = ladderPx - (lmt * ws_util.tickSize(symbol));

    if (price > ladderPxMaxUp) {
      cancel_limit_order_all(
          channel: channelMaster, symbol: symbol, px: price, side: '');
      return false;
    }
    if (price < ladderPxMinDw) {
      cancel_limit_order_all(
          channel: channelMaster, symbol: symbol, px: price, side: '');
      return false;
    }

    if (!active_orders_ListPx_controll.contains(price)) {
      cancel_limit_order_all(
          channel: channelMaster, symbol: symbol, px: price, side: '');
      return false;
    }

    return true;
  }

  Future handle_order_cancelled(ws, msg) async {
    Map data = msg['data'];
    var status = data['orderStatus'];

    if (status == 'REJECTED' && data.containsKey('errCode')) {
      var error_code = data['errCode'];

      if (env['print_error'] == 'true') {
        print('order cancellation REJECTED with error code: ${error_code}');
      }

      return null;
    }

    if (data.containsKey('errCode')) {
      return null;
    }

    data['orders'].forEach((order) async {
      var cancelled_order_id = order['oldClOrdId'];
      //print('order ${cancelled_order_id} has been CANCELLED');
      //print(active_orders[cancelled_order_id]);
      if (active_orders.containsKey('$cancelled_order_id')) {
        if (funzioneRound(msg['data']['symbol'],
            active_orders[cancelled_order_id]['px'].toDouble())) {
          //print(active_orders[cancelled_order_id]['px']);
          active_orders_ListPx.remove(active_orders[cancelled_order_id]['px']);
          active_orders.remove(cancelled_order_id);
        }
      }
    });

    //print('active orders handle_order_cancelled: ${active_orders}');
  }

  funzione_Balance(bilancio, symbol) async {
    var stop = env['stopBalance'];
    var take = env['takeBalance'];
    var metod_S = env['metodoBalanceS'];
    var metod_T = env['metodoBalanceT'];
    if (stop != '0' &&
        bilancio.isNegative &&
        bilancio.abs() >= double.parse(stop)) {
      print(
          'BALANCE (${metod_S}) stop (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');

      if (metod_S == 'closeAll_stopScript') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        var time = Duration(seconds: 1);
        await Future.delayed(time);
        exit(0);
      }
      if (metod_S == 'closeAll_continue') {
        bilancio = 0;
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print('CLOSE ALL AND ... ${DateTime.now()}');
        balance_Start = 0.0;

        var time = Duration(seconds: int.parse(env['DelayStop']));
        await Future.delayed(time);
        print('CONTINUE...${DateTime.now()}');
        startBotTrading = true;
        print(
            'BALANCE (${metod_S}) restart (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_S == 'closeAll_stop') {
        bilancio = 0;
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        balance_Start = 0.0;
        print(
            'BALANCE (${metod_S}) stop (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_S == 'closeSoft') {
        bilancio = 0;
        //print(upnl);
        if (upnl > double.parse(env['SogliaCloseSoft']) ||
            env['SogliaCloseSoft'] == '0') {
          await funzione_closeAll_Limit(symbol);
          await funzione_closeAll_Contract(symbol);
          balance_Start = 0.0;
          funzione_StopBot();
          print(
              'BALANCE (${metod_S}) stop soft (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
        }
      }
    }
    if (take != '0' &&
        !bilancio.isNegative &&
        bilancio.abs() >= double.parse(take)) {
      print(
          'BALANCE (${metod_T}) stop (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');

      if (metod_T == 'closeAll_stopScript') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        var time = Duration(seconds: 1);
        await Future.delayed(time);
        exit(0);
      }
      if (metod_T == 'closeAll_continue') {
        bilancio = 0;
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print('CLOSE ALL AND ... ${DateTime.now()}');
        balance_Start = 0.0;
        var time = Duration(seconds: int.parse(env['DelayTake']));
        await Future.delayed(time);
        print('CONTINUE...${DateTime.now()}');
        startBotTrading = true;
        print(
            'BALANCE (${metod_T}) restart (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_T == 'closeAll_stop') {
        bilancio = 0;
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        balance_Start = 0.0;
        print(
            'BALANCE (${metod_T}) stop (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_T == 'closeSoft') {
        bilancio = 0;
        //print(upnl);
        if (upnl > double.parse(env['SogliaCloseSoft']) ||
            env['SogliaCloseSoft'] == '0') {
          await funzione_closeAll_Limit(symbol);
          await funzione_closeAll_Contract(symbol);
          balance_Start = 0.0;
          funzione_StopBot();
          print(
              'BALANCE (${metod_T}) stop soft (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');
        }
      }
    }
  }

  funzione_UPnL(bilancio, symbol) async {
    var stop = env['stopUPnL'];
    var take = env['takeUPnL'];
    var metod_S = env['metodoUPnLS'];
    var metod_T = env['metodoUPnLT'];
    if (stop != '0' && upnl.isNegative && upnl.abs() >= double.parse(stop)) {
      print(
          'UPnL (${metod_S}) stop (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');

      if (metod_S == 'closeAll_stopScript') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        var time = Duration(seconds: 1);
        await Future.delayed(time);
        exit(0);
      }
      if (metod_S == 'closeAll_continue') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print('CLOSE ALL AND ... ${DateTime.now()}');

        var time = Duration(seconds: int.parse(env['DelayStop']));
        await Future.delayed(time);
        print('CONTINUE...${DateTime.now()}');
        startBotTrading = true;
        print(
            'UPnL (${metod_S}) restart (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_S == 'closeAll_stop') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print(
            'UPnL (${metod_S}) stop (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_S == 'closeSoft') {
        //print(upnl);
        if (upnl > double.parse(env['SogliaCloseSoft']) ||
            env['SogliaCloseSoft'] == '0') {
          await funzione_closeAll_Limit(symbol);
          await funzione_closeAll_Contract(symbol);
          funzione_StopBot();
          print(
              'UPnL (${metod_S}) stop soft (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
        }
      }
    }
    if (take != '0' && !upnl.isNegative && upnl.abs() >= double.parse(take)) {
      print(
          'UPnL (${metod_T}) stop (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');

      if (metod_T == 'closeAll_stopScript') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        var time = Duration(seconds: 1);
        await Future.delayed(time);
        exit(0);
      }
      if (metod_T == 'closeAll_continue') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print('CLOSE ALL AND ... ${DateTime.now()}');
        var time = Duration(seconds: int.parse(env['DelayTake']));
        await Future.delayed(time);
        print('CONTINUE...${DateTime.now()}');
        startBotTrading = true;
        print(
            'UPnL (${metod_T}) restart (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_T == 'closeAll_stop') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print(
            'UPnL (${metod_T}) stop (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_T == 'closeSoft') {
        //print(upnl);
        if (upnl > double.parse(env['SogliaCloseSoft']) ||
            env['SogliaCloseSoft'] == '0') {
          await funzione_closeAll_Limit(symbol);
          await funzione_closeAll_Contract(symbol);
          funzione_StopBot();
          print(
              'UPnL (${metod_T}) stop soft (takeprofit): ${balance} - ${bilancio} - ${DateTime.now()}');
        }
      }
    }
  }

  funzione_open_contracts(bilancio, symbol) async {
    var stop_take = env['stopOpen_Contracts'];
    var metod_S_T = env['metodoOpen_Contracts'];
    //print('funzione_open_contracts: bilancio $bilancio');
    if (stop_take != '0' && bilancio >= double.parse(stop_take)) {
      if (env['print_limit_order'] == 'true') {
        print(
            'CNT (${metod_S_T}) stop (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }

      if (metod_S_T == 'closeAll_stopScript') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        var time = Duration(seconds: 1);
        await Future.delayed(time);
        exit(0);
      }
      if (metod_S_T == 'closeAll_continue') {
        bilancio = 0;
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        print('CLOSE ALL AND ... ${DateTime.now()}');
        open_contracts_start = 0;

        var time = Duration(seconds: int.parse(env['DelayStop']));
        await Future.delayed(time);
        print('CONTINUE...${DateTime.now()}');
        startBotTrading = true;
        print(
            'CNT (${metod_S_T}) restart (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_S_T == 'closeAll_stop') {
        //bilancio = 0;
        //controlCancellAll = true;
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        funzione_StopBot();
        open_contracts_start = 0;
        print(
            'CNT (${metod_S_T}) stop (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
      }
      if (metod_S_T == 'closeSoft') {
        bilancio = 0;
        //print(upnl);
        if (upnl > double.parse(env['SogliaCloseSoft']) ||
            env['SogliaCloseSoft'] == '0') {
          await funzione_closeAll_Limit(symbol);
          await funzione_closeAll_Contract(symbol);
          open_contracts_start = 0;
          funzione_StopBot();
          print(
              'CNT (${metod_S_T}) stop soft (stoploss): ${balance} - ${bilancio} - ${DateTime.now()}');
        }
      }

      if (metod_S_T == 'stopLimit') {
        if (data_trade['positionType'] == 'SHORT' && attiva_SELL) {
          attiva_SELL = false;
          attiva_BUY = true;
          await cancel_limit_order_all(
              channel: channelMaster, symbol: symbol, px: 0, side: 'SELL');
        }
        if (data_trade['positionType'] == 'LONG' && attiva_BUY) {
          attiva_BUY = false;
          attiva_SELL = true;
          await cancel_limit_order_all(
              channel: channelMaster, symbol: symbol, px: 0, side: 'BUY');
        }
        open_contracts_start = 0;
        if (env['print_limit_order'] == 'true') {
          print(
              'CNT (${metod_S_T}) stop limit: ${balance} - ${bilancio} - ${DateTime.now()}');
        }
      }
    } else if (stop_take != '0' &&
        bilancio < double.parse(stop_take) &&
        (!attiva_BUY || !attiva_SELL)) {
      attiva_BUY = true;
      attiva_SELL = true;
    }
  }

  Future funzione_closeAll_Limit(symbol) async {
    await cancel_limit_order_all(
        channel: channelMaster, symbol: symbol, px: 0, side: '');
    var time = Duration(milliseconds: 100);
    return await Future.delayed(time);
  }

  Future funzione_closeAll_Contract(symbol) async {
    if (open_contracts_start > 0) {
      await close_position(
          channel: channelMaster, symbol: symbol, px: 0, ord_type: 'MARKET');
      var time = Duration(milliseconds: 50);
      return await Future.delayed(time);
    }
  }

  void funzione_StopBot() {
    startBotTrading = false;
    //startBotTrading = true;
    //controlCancellAll = false;
  }

  bool funzioneRound(String symbol, double price) {
    if (env['Alternate'] == 'false') {
      return true;
    } else if (env['Alternate'] == 'true') {
      //print(symbol);
      if (symbol == 'BTCUSD') {
        var pr = price.toInt().toString();
        return pr.endsWith('5');
      }
      if (symbol == 'ETHUSD') {
        var pr = (price * 100).toInt().toString();
        print(pr);
        return pr.endsWith('5');
      }
      if (symbol == 'XRPUSD') {
        return price.toInt().isOdd;
      }
      if (symbol == 'BTCUSD1') {
        return price.toInt().isOdd;
      }
      if (symbol == 'XAUUSD') {
        var pr = price.toString();
        return pr.endsWith('5');
      }
      if (symbol == 'AMZNUSD') {
        return price.toInt().isOdd;
      }
    }

    return false;
  }

  Future<bool> funzione_Orario(symbol) async {
    if (stop_time == 'false') {
      stop_time = 'true';
    }
    final now = DateTime.now();
    var metod = env['metodoOrario'];
    if (env['sess1'] == 'true') {
      final startTime = DateTime.parse(
          '${now.year}-${time_format(now.month)}-${time_format(now.day)} ${env['session1start']}:00');
      final endTime = DateTime.parse(
          '${now.year}-${time_format(now.month)}-${time_format(now.day)} ${env['session1end']}:00');
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        if (env['print_orario'] == 'true') {
          print('IN ORARIO ${now}');
        }
        if (funzione_ST()) {
          startBotTrading = true;
        }
        //startBotTrading = true;
        stop_time = 'false';
        return (true);
      }
    }
    if (env['sess2'] == 'true') {
      final startTime = DateTime.parse(
          '${now.year}-${time_format(now.month)}-${time_format(now.day)} ${env['session2start']}:00');
      final endTime = DateTime.parse(
          '${now.year}-${time_format(now.month)}-${time_format(now.day)} ${env['session2end']}:00');
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        if (env['print_orario'] == 'true') {
          print('IN ORARIO ${now}');
        }
        if (funzione_ST()) {
          startBotTrading = true;
        }

        stop_time = 'false';
        return (true);
      }
    }
    if (env['sess3'] == 'true') {
      final startTime = DateTime.parse(
          '${now.year}-${time_format(now.month)}-${time_format(now.day)} ${env['session3start']}:00');
      final endTime = DateTime.parse(
          '${now.year}-${time_format(now.month)}-${time_format(now.day)} ${env['session3end']}:00');
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        if (env['print_orario'] == 'true') {
          print('IN ORARIO ${now}');
        }

        if (funzione_ST()) {
          startBotTrading = true;
        }
        stop_time = 'false';
        return (true);
      }
    }

    if (env['sess1'] == 'false' &&
        env['sess2'] == 'false' &&
        env['sess3'] == 'false') {
      if (funzione_ST()) {
        startBotTrading = true;
      }
      stop_time = 'false';
      return (true);
    }
    if (env['print_orario'] == 'true') {
      print('FUORI ORARIO ${now}');
    }

    if (stop_time == 'true') {
      if (metod == 'closeAll_stopScript') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        var time = Duration(seconds: 1);
        await Future.delayed(time);
        exit(0);
      }

      if (metod == 'closeAll_continue') {
        print('NON PUOI SELEZIONARE closeAll_continue PER L OPZIONE ORARI');
      }
      if (metod == 'closeAll_stop') {
        funzione_StopBot();
        await funzione_closeAll_Limit(symbol);
        await funzione_closeAll_Contract(symbol);
        open_contracts_start = 0;
        balance_Start = 0.0;
        ladderPx_List_DW = {};
        ladderPx_List_UP = {};
        balance = 0.0;
        balance_Start = 0.0;
        upnl_Start = 0.0;
      }
      if (metod == 'closeSoft') {
        //print(upnl);
        if (upnl > double.parse(env['SogliaCloseSoft']) ||
            env['SogliaCloseSoft'] == '0') {
          await funzione_closeAll_Limit(symbol);
          await funzione_closeAll_Contract(symbol);
          open_contracts_start = 0;
          balance_Start = 0.0;
          ladderPx_List_DW = {};
          ladderPx_List_UP = {};
          balance = 0.0;
          balance_Start = 0.0;
          upnl_Start = 0.0;

          funzione_StopBot();
        }
      }
    }
    return (false);
  }

  String time_format(n) {
    var str = '${n}';
    if (n < 10) {
      str = '0${n}';
    }
    return str;
  }

  bool funzione_ST() {
    if (env['stopBalance'] == '0' &&
        env['takeBalance'] == '0' &&
        env['stopUPnL'] == '0' &&
        env['takeUPnL'] == '0' &&
        env['stopOpen_Contracts'] == '0') {
      return true;
    } else {
      return false;
    }
  }

  Future handle_ticker(ws, msg) async {
    var ticker = msg['data'];
    // ignore: unused_local_variable
    var open_ts = ticker['openTime'];
    // ignore: unused_local_variable
    var close_ts = ticker['closeTime'];
    // ignore: unused_local_variable
    var high_px = ticker['highPx24h'];
    // ignore: unused_local_variable
    var low_px = ticker['lowPx24h'];
    // ignore: unused_local_variable
    var px_change = ticker['pxChange24h'];
    // ignore: unused_local_variable
    var volume24h = ticker['volume24h'];
    // ignore: unused_local_variable
    var funding_rate = ticker['fundingRate'];
    // ignore: unused_local_variable
    contract_value = ticker['contractValue'].toDouble() / leverage;
    // ignore: unused_local_variable
    var dgtx_rate = ticker['dgtxUsdRate'];
    //print('got 24 stats: from=${open_ts} to=${close_ts} high_price=${high_px} '
    //'low_price=${low_px} price_change=${px_change} volume=${volume24h} '
    //'funding_rate=${funding_rate} contract_value=${contract_value} DGTX/USD=${dgtx_rate}');
  }

  funzioneControlloOrdini(items) async {
    // var lmt_down = int.parse(env['DeltaOrdini']);

    // var ladderPxMax_Near =
    //     ladderPx + (lmt_down * ws_util.tickSize(items['symbol']));
    // var ladderPxMin_Near =
    //     ladderPx - (lmt_down * ws_util.tickSize(items['symbol']));

    var list = [];
    // if (env['Liquidity'] == 'true' && items['activeOrders'].isNotEmpty) {
    //   if (items['activeOrders'].first['px'] <= ladderPxMax_Near) {
    //     // print(
    //     //     'Cancell order liquidity - side: ${u['orderSide']} id: ${u['clOrdId']} px: ${u['px']}');
    //     await cancel_limit_order_all(
    //         channel: channelMaster,
    //         symbol: items['symbol'],
    //         px: items['activeOrders'].first['px'],
    //         side: '');
    //     //list.add(items['activeOrders'].first['px']);
    //   }
    //   if (items['activeOrders'].first['px'] >= ladderPxMin_Near) {
    //     // print(
    //     //     'Cancell order liquidity - side: ${u['orderSide']} id: ${u['clOrdId']} px: ${u['px']}');
    //     await cancel_limit_order_all(
    //         channel: channelMaster,
    //         symbol: items['symbol'],
    //         px: items['activeOrders'].last['px'],
    //         side: '');
    //     //list.add(items['activeOrders'].first['px']);
    //   }
    // }

    items['activeOrders'].forEach((u) {
      //print('U: ${u}');
      if (list.contains(u['px'])) {
        //print('duplicate ${u['px']}');
        if (env['print_cancel'] == 'true') {
          print(
              'Cancell order duplicate - side: ${u['orderSide']} qty: ${u['qty']} px: ${u['px']}');
        }

        cancel_limit_order_all(
            channel: channelMaster,
            symbol: items['symbol'],
            px: u['px'],
            side: '');
      } else {
        list.add(u['px']);
      }
      if (u['qty'] > amount_B && u['orderSide'] == 'BUY') {
        if (env['print_cancel'] == 'true') {
          print(
              'Cancell order != amount_B - side: ${u['orderSide']} qty: ${u['qty']} px: ${u['px']}');
        }
        cancel_limit_order_all(
            channel: channelMaster,
            symbol: items['symbol'],
            px: u['px'],
            side: 'BUY');
      }
      if (u['qty'] > amount_S && u['orderSide'] == 'SELL') {
        if (env['print_cancel'] == 'true') {
          print(
              'Cancell order != amount_S - side: ${u['orderSide']} qty: ${u['qty']} px: ${u['px']}');
        }
        cancel_limit_order_all(
            channel: channelMaster,
            symbol: items['symbol'],
            px: u['px'],
            side: 'SELL');
      }
    });
  }

  //
  //end class
}
