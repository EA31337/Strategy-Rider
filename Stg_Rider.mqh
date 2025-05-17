/**
 * @file
 * Implements Rider strategy based on the Rider indicator.
 */

// User input params.
INPUT_GROUP("Rider strategy: strategy params");
INPUT float Rider_LotSize = 0;                // Lot size
INPUT int Rider_SignalOpenMethod = 0;         // Signal open method
INPUT float Rider_SignalOpenLevel = 0;        // Signal open level
INPUT int Rider_SignalOpenFilterMethod = 32;  // Signal open filter method
INPUT int Rider_SignalOpenFilterTime = 3;     // Signal open filter time (0-31)
INPUT int Rider_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int Rider_SignalCloseMethod = 0;        // Signal close method
INPUT int Rider_SignalCloseFilter = 32;       // Signal close filter (-127-127)
INPUT float Rider_SignalCloseLevel = 0;       // Signal close level
INPUT int Rider_PriceStopMethod = 0;          // Price limit method
INPUT float Rider_PriceStopLevel = 2;         // Price limit level
INPUT int Rider_TickFilterMethod = 32;        // Tick filter method (0-255)
INPUT float Rider_MaxSpread = 4.0;            // Max spread to trade (in pips)
INPUT short Rider_Shift = 0;                  // Shift
INPUT float Rider_OrderCloseLoss = 80;        // Order close loss
INPUT float Rider_OrderCloseProfit = 80;      // Order close profit
INPUT int Rider_OrderCloseTime = -30;         // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("Rider strategy: Rider indicator params");
INPUT int Rider_Indi_Rider_Shift = 0;                                        // Shift
INPUT ENUM_IDATA_SOURCE_TYPE Rider_Indi_Rider_SourceType = IDATA_INDICATOR;  // Source type

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
    Set(STRAT_PARAM_SOFT, Rider_SignalOpenFilterTime);
  }
};

class Stg_Rider : public Strategy {
 public:
  Stg_Rider(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {}

  static Stg_Rider *Init(ENUM_TIMEFRAMES _tf = NULL, EA* _ea = NULL) {
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
   * Event on strategy's init.
   */
  void OnInit() {
    // Initialize indicators.
    // IndiRiderParams _indi_params(::Rider_Indi_Rider_Shift);
    /*
    _indi_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_Rider(_indi_params));
    */
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method, float _level = 0.0f, int _shift = 0) {
    //Indi_Rider *_indi = GetIndicator();
    // bool _result = _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift) && _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift + 1);
    bool _result = true;
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    /*
    IndicatorSignal _signals = _indi.GetSignals(4, _shift);
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // Buy signal.
        _result &= _indi.IsIncreasing(1, 0, _shift);
        _result &= _indi.IsIncByPct(_level / 10, 0, _shift, 2);
        _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        break;
      case ORDER_TYPE_SELL:
        // Sell signal.
        _result &= _indi.IsDecreasing(1, 0, _shift);
        _result &= _indi.IsDecByPct(_level / 10, 0, _shift, 2);
        _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        break;
    }
    */
    return _result;
  }
};
