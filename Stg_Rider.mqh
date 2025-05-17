/**
 * @file
 * Implements Rider strategy based on the Rider indicator.
 */

// User input params.
INPUT_GROUP("Rider strategy: strategy params");
INPUT float Rider_LotSize = 0;                 // Lot size
INPUT int Rider_SignalOpenMethod = 0;          // Signal open method
INPUT float Rider_SignalOpenLevel = 0;         // Signal open level
INPUT int Rider_SignalOpenFilterMethod = 160;  // Signal open filter method
INPUT int Rider_SignalOpenFilterTime = 3;      // Signal open filter time (0-31)
INPUT int Rider_SignalOpenBoostMethod = 0;     // Signal open boost method
INPUT int Rider_SignalCloseMethod = 0;         // Signal close method
INPUT int Rider_SignalCloseFilter = 0;         // Signal close filter (-127-127)
INPUT float Rider_SignalCloseLevel = 0;        // Signal close level
INPUT int Rider_PriceStopMethod = 0;           // Price limit method
INPUT float Rider_PriceStopLevel = 0;          // Price limit level
INPUT int Rider_TickFilterMethod = 4;          // Tick filter method (0-255)
INPUT float Rider_MaxSpread = 4.0;             // Max spread to trade (in pips)
INPUT short Rider_Shift = 0;                   // Shift
INPUT float Rider_OrderCloseLoss = 80;         // Order close loss
INPUT float Rider_OrderCloseProfit = 0;        // Order close profit
INPUT int Rider_OrderCloseTime = -10;          // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("Rider strategy: Rider custom params");
INPUT ENUM_PP_TYPE Rider_Trend_Pivot_Type = PP_WOODIE;  // Pivot type for trend calculation
INPUT ENUM_TIMEFRAMES Rider_Trend_Tf = PERIOD_H1;       // Trend timeframe calculation
INPUT float Rider_Trend_Threshold = 0.1f;               // Trend treshold
INPUT_GROUP("Rider strategy: Rider indicator params");
INPUT int Rider_Indi_RSI_Period = 16;                                    // Period
INPUT ENUM_APPLIED_PRICE Rider_Indi_RSI_Applied_Price = PRICE_WEIGHTED;  // Applied Price
INPUT int Rider_Indi_RSI_Shift = 0;                                      // Shift

// Structs.

// Defines struct with default user strategy values.
struct Stg_Rider_Params_Defaults : StgParams {
  Stg_Rider_Params_Defaults()
      : StgParams(::Rider_SignalOpenMethod, ::Rider_SignalOpenFilterMethod, ::Rider_SignalOpenLevel,
                  ::Rider_SignalOpenBoostMethod, ::Rider_SignalCloseMethod, ::Rider_SignalCloseFilter,
                  ::Rider_SignalCloseLevel, ::Rider_PriceStopMethod, ::Rider_PriceStopLevel, ::Rider_TickFilterMethod,
                  ::Rider_MaxSpread, ::Rider_Shift) {
    Set(STRAT_PARAM_LS, Rider_LotSize);
    Set(STRAT_PARAM_OCL, Rider_OrderCloseLoss);
    Set(STRAT_PARAM_OCP, Rider_OrderCloseProfit);
    Set(STRAT_PARAM_OCT, Rider_OrderCloseTime);
    Set(STRAT_PARAM_SHIFT, Rider_Shift);
    Set(STRAT_PARAM_SOFT, Rider_SignalOpenFilterTime);
    trend_threshold = ::Rider_Trend_Threshold;  // @todo: Implement Set().
  }
};

class Stg_Rider : public Strategy {
 protected:
  // Stg_Rider_Params_Defaults ssparams;
  Trade strade;
  float pricestop_value;

 public:
  Stg_Rider(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name), strade(_tparams, _cparams) {}

  static Stg_Rider *Init(ENUM_TIMEFRAMES _tf = NULL, EA *_ea = NULL) {
    // Initialize strategy initial values.
    Stg_Rider_Params_Defaults stg_rider_defaults;
    StgParams _stg_params(stg_rider_defaults);
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Strategy *_strat = new Stg_Rider(_stg_params, _tparams, _cparams, "Rider");
    return _strat;
  }

  /**
   * Calculates price stop values for orders.
   *
   * It's estimating a single price at which the account equity drops to zero,
   * assuming all active order's stop losses are set to that price.
   */
  float CalcPriceStop() {
    double balance = trade.account.GetBalance();
    double equity = trade.account.GetEquity();  // Or use balance as starting point
    double totalBuyLots = 0.0, totalSellLots = 0.0;
    double buyOpenSum = 0.0, sellOpenSum = 0.0;
    string symbol = trade.GetChart().GetSymbol();

    double tickValue = SymbolInfoStatic::SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoStatic::SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    float _pricestop_value = 0;

    // Traverse active orders.
    DictStruct<long, Ref<Order>> *orders = strade.GetOrdersActive();
    for (DictStructIterator<long, Ref<Order>> iter = orders.Begin(); iter.IsValid(); ++iter) {
      Ref<Order> refOrder = iter.Value();
      Order *order = refOrder.Ptr();
      if (!order.IsOpen()) continue;

      double lots = order.Get<float>(ORDER_VOLUME_CURRENT);  // order.GetVolume(); // @todo: Returns 0.
      double openPrice = order.GetOpenPrice();
      ENUM_ORDER_TYPE type = order.GetType();

      if (type == ORDER_TYPE_BUY) {
        totalBuyLots += lots;
        buyOpenSum += lots * openPrice;
      } else if (type == ORDER_TYPE_SELL) {
        totalSellLots += lots;
        sellOpenSum += lots * openPrice;
      }
    }

    // Weighted average open prices
    double buyAvgOpen = totalBuyLots > 0 ? buyOpenSum / totalBuyLots : 0.0;
    double sellAvgOpen = totalSellLots > 0 ? sellOpenSum / totalSellLots : 0.0;

    // Equation: balance + (floating profit at price X) == 0
    // For all BUY: profit = (X - OpenPrice) * Lots / TickSize * TickValue
    // For all SELL: profit = (OpenPrice - X) * Lots / TickSize * TickValue

    // Simplify:
    // 0 = balance + (X - buyAvgOpen) * totalBuyLots / tickSize * tickValue
    //             + (sellAvgOpen - X) * totalSellLots / tickSize * tickValue

    // Combine:
    // 0 = balance + tickValue / tickSize * [totalBuyLots * (X - buyAvgOpen) + totalSellLots * (sellAvgOpen - X)]
    // 0 = balance + tickValue / tickSize * (X * (totalBuyLots - totalSellLots) - (buyAvgOpen * totalBuyLots -
    // sellAvgOpen * totalSellLots)) Solve for X:

    double lotsDiff = totalBuyLots - totalSellLots;
    double A = tickValue / tickSize * lotsDiff;
    double B = tickValue / tickSize * (buyAvgOpen * totalBuyLots - sellAvgOpen * totalSellLots);

    if (MathAbs(A) > 1e-8) {
      // _pricestop_value = (float)(( -balance + B ) / A);
      _pricestop_value = (float)(buyAvgOpen - balance / ((tickValue / tickSize) * totalBuyLots));
    } else {
      _pricestop_value = 0.0f;  // Flat or no positions
    }

    return _pricestop_value;
  }

  /**
   * Checks if the current price is in trend given the order type.
   */
  bool IsTrend(ENUM_ORDER_TYPE _cmd, ENUM_TIMEFRAMES _tf = PERIOD_D1, int _shift = 0) {
    // @todo: Make IsTrend() a virtual class.
    bool _result = false;
    double _tvalue = TrendStrength(_tf, _shift);
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        _result = _tvalue > sparams.trend_threshold;
        break;
      case ORDER_TYPE_SELL:
        _result = _tvalue < -sparams.trend_threshold;
        break;
    }
    return _result;
  }

  /**
   * Event on strategy's init.
   */
  void OnInit() {
    // Initialize indicators.
    IndiRSIParams _indi_params(::Rider_Indi_RSI_Period, ::Rider_Indi_RSI_Applied_Price, ::Rider_Indi_RSI_Shift);
    _indi_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_RSI(_indi_params));

    DictStruct<long, Ref<Order>> _orders_active = strade.GetOrdersActive();
    _orders_active.Clear();
    OrdersLoadByMagic();
  }

  /**
   * Event on strategy's order open.
   */
  virtual void OnOrderOpen(OrderParams &_oparams) {
    Strategy::OnOrderOpen(_oparams);
    // trade.orders_active.Set(_order.Get<ulong>(ORDER_PROP_TICKET), _ref_order);
    // @todo: We need OnOrderOpen after order is opened.
  }

  /**
   * Event on new time periods.
   */
  virtual void OnPeriod(unsigned int _periods = DATETIME_NONE) {
    if ((_periods & DATETIME_MINUTE) != 0) {
      // New minute started.
      DictStruct<long, Ref<Order>> _orders_active = strade.GetOrdersActive();
      _orders_active.Clear();
      OrdersLoadByMagic();
      // strade.RefreshActiveOrders(true, true);
      strade.UpdateStates();
      if (strade.Get<bool>(TRADE_STATE_ORDERS_ACTIVE)) {
        pricestop_value = CalcPriceStop();
      }
    }
    if ((_periods & DATETIME_HOUR) != 0) {
      // New hour started.
    }
    if ((_periods & DATETIME_DAY) != 0) {
      // New day started.
    }
  }

  /**
   * Loads active orders by magic number.
   */
  bool OrdersLoadByMagic() {
    ResetLastError();
    int _total_active = TradeStatic::TotalActive();
    unsigned long _magic_no = Get<long>(STRAT_PARAM_ID);  // strade.Get<long>(TRADE_PARAM_MAGIC_NO);
    DictStruct<long, Ref<Order>> *_orders_active = strade.GetOrdersActive();
    for (int pos = 0; pos < _total_active; pos++) {
      if (OrderStatic::SelectByPosition(pos)) {
        unsigned long _magic_no_order = OrderStatic::MagicNumber();
        if (_magic_no_order == _magic_no) {
          unsigned long _ticket = OrderStatic::Ticket();
          if (!_orders_active.KeyExists(_ticket)) {
            Ref<Order> _order = new Order(_ticket);
            _order.Ptr().Refresh(ORDER_VOLUME_CURRENT);
            if (_order.Ptr().Get<float>(ORDER_VOLUME_CURRENT) <= 0.0f) {
              // @fixme
              _order.Ptr().Set(ORDER_VOLUME_CURRENT, strade.GetChart().GetVolumeMin());
              ResetLastError();
            }
            _orders_active.Set(_ticket, _order);
          }
        }
      }
    }
    return GetLastError() == ERR_NO_ERROR;
  }

  /**
   * Gets price stop value.
   */
  virtual float PriceStop(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, float _level = 0.0f,
                          short _bars = 4) {
    // return Strategy::PriceStop(_cmd, _mode, _method, _level, _bars);
    return pricestop_value;
  }

  /**
   * Check strategy's closing signal.
   */
  bool SignalClose(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    MarketTimeForex mktTime;
    int currHour = mktTime.hour;
    int nyOpenHour = mktTime.GetOpenHour(MarketTimeForex::MARKET_TIME_FOREX_HOURS_NEWYORK);
    int nyCloseHour = mktTime.GetCloseHour(MarketTimeForex::MARKET_TIME_FOREX_HOURS_NEWYORK);
    // @todo: Add close signal when outside of trading hours.
    return (currHour == nyOpenHour || currHour == nyCloseHour);
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method, float _level = 0.0f, int _shift = 0) {
    Indi_RSI *_indi = GetIndicator();
    bool _result =
        _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift) && _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift + 1);
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    IndicatorSignal _signals = _indi.GetSignals(4, _shift);
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // Buy signal.
        _result &= _indi.IsDecreasing(1, 0, _shift);
        // _result &= _indi.IsIncByPct(_level / 10, 0, _shift, 2);
        // _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        break;
      case ORDER_TYPE_SELL:
        // Sell signal.
        _result &= _indi.IsIncreasing(1, 0, _shift);
        // _result &= _indi.IsDecByPct(_level / 10, 0, _shift, 2);
        // _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        break;
    }
    return _result;
  }

  /**
   * Checks strategy's trade's open signal method filter.
   */
  virtual bool SignalOpenFilterMethod(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = true;
    if (_method != 0) {
      _result = Strategy::SignalOpenFilterMethod(_cmd, _method);
      _result &= IsTrend(_cmd, ::Rider_Trend_Tf, Get<ENUM_STRATEGY_PARAM>(STRAT_PARAM_SHIFT));
      if (METHOD(_method, 7))
        _result &= !trade.HasActiveOrders() ||
                   !trade.CheckCondition(TRADE_COND_ACCOUNT, _method > 0 ? ACCOUNT_COND_EQUITY_IN_PROFIT
                                                                         : ACCOUNT_COND_EQUITY_IN_LOSS);  // 128
    }
    return _result;
  }

  /**
   * Gets trend strength value.
   *
   * @param
   *   _tf - timeframe to use for trend calculation
   *
   * @result bool
   *   Returns trend strength value from -1 (strong bearish) to +1 (strong bullish).
   *   Value closer to 0 indicates a neutral trend.
   */
  float TrendStrength(ENUM_TIMEFRAMES _tf = PERIOD_D1, int _shift = 1) {
    float _result = 0;
    Chart *_c = trade.GetChart();
    if (_c.IsValidShift(_shift)) {
      ChartEntry _bar1 = _c.GetEntry(_tf, _shift);
      float _range = _bar1.bar.ohlc.GetRange();
      if (_range > 0) {
        float _pp, _r1, _r2, _r3, _r4, _s1, _s2, _s3, _s4;
        float _close = (float)_c.GetClose(_tf);  // @todo: Transfer fix to classes.
        // float _pp = _bar1.bar.ohlc.GetPivot();
        _bar1.bar.ohlc.GetPivots(::Rider_Trend_Pivot_Type, _pp, _r1, _r2, _r3, _r4, _s1, _s2, _s3, _s4);
        _result = 1 / _range * (_close - _pp);
        _result = fmin(1, fmax(-1, _result));
      }
    }
    return _result;
  };
};
