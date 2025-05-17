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
  }

  /**
   * Event on new time periods.
   */
  virtual void OnPeriod(unsigned int _periods = DATETIME_NONE) {
    if ((_periods & DATETIME_MINUTE) != 0) {
      // New minute started.
    }
    if ((_periods & DATETIME_HOUR) != 0) {
      // New hour started.
      OrdersLoadByMagic();
    }
    if ((_periods & DATETIME_DAY) != 0) {
      // New day started.
      /*
      DictStruct<long, Ref<Order>> _orders_active = strade.GetOrdersActive();
      _orders_active.Clear();
      OrdersLoadByMagic();
      */
    }
  }

  /**
   * Loads active orders by magic number.
   */
  bool OrdersLoadByMagic() {
    double _opricemax = 0.0, _opricemin = DBL_MAX;
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
            double _order_price_open = _order.Ptr().Get<float>(ORDER_PROP_PRICE_OPEN);
            if (_order_price_open > _opricemax) {
              _opricemax = _order_price_open;
            } else if (_order_price_open < _opricemin) {
              _opricemin = _order_price_open;
            }
            _orders_active.Set(_ticket, _order);
          }
        }
      }
    }
    if (_opricemax != 0.0) {
      // ssparams.SetPriceMax(_opricemax);
    }
    if (_opricemin != 0.0) {
      // ssparams.SetPriceMin(_opricemin);
    }
    return GetLastError() == ERR_NO_ERROR;
  }

  /**
   * Gets price stop value.
   */
  virtual float PriceStop(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, float _level = 0.0f,
                          short _bars = 4) {
    return Strategy::PriceStop(_cmd, _mode, _method, _level, _bars);
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
