//+------------------------------------------------------------------+
//|                                                 ShadowRecord.mqh |
//|                                 Copyright 2017, Keisuke Iwabuchi |
//|                                        https://order-button.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Keisuke Iwabuchi"
#property link      "https://order-button.com/"
#property strict


#ifndef _LOAD_MODULE_SHADOW_RECORD
#define _LOAD_MODULE_SHADOW_RECORD


/** Create and manage virtual trade records. */
class ShadowRecord
{
   // variables and structures
   protected:
      int    error_code;
      int    record_count;
      int    select_element;
      int    max_record_count;
      /** @var bool show_arrw Display arrows on charts when virtual trading. */
      bool   show_arrow;
      string record_file_name;
      string statement_file_name;
   
   struct Record {
      int      ticket;
      bool     valid;
      bool     open;
      datetime open_time;
      datetime close_time;
      uchar    symbol[10];
      int      cmd;
      double   volume;
      double   open_price;
      double   close_price;
      double   stoploss;
      double   takeprofit;
      int      magic;
      datetime expiration;
   };
   
   public:
      Record records[];
   
   
   // methods
   protected:
      void CheckCloseRecords(const int shift = 0);
      void CheckExpirationRecords(const int shift = 0);
      void CheckOpenRecords(const int shift = 0);
      int  GetElement(const int ticket);

   public:
      void     ArrowCreate(int id, int type, color arrow_color);
      void     ArrowDelete(const int id);
      double   CurrentRecords(int type, string symbol, int magic);
      void     Deinit(void);
      int      GetLastErrorRecord(void);
      int      GetMaxRecordCount(void);
      int      GetRecordCount(void);
      void     Init(void);
      bool     Load(string file=NULL);
      string   PeriodToString(int period);
      bool     RecordClose(int    ticket, 
                           double lots, 
                           double price, 
                           int    slippage, 
                           color  arrow_color);
      double   RecordClosePrice(void);
      datetime RecordCloseTime(void);
      double   RecordCommission(void);
      bool     RecordDelete(int ticket, color arrow_color=clrNONE);
      datetime RecordExpiration(void);
      double   RecordLots(void);
      int      RecordMagicNumber(void);
      bool     RecordModify(int      ticket,
                            double   price, 
                            double   stoploss, 
                            double   takeprofit, 
                            datetime expiration, 
                            color    arrow_color
                            );
      double   RecordOpenPrice(void);
      datetime RecordOpenTime(void);
      double   RecordProfit(void);
      bool     RecordSelect(int index, int select, int pool=MODE_TRADES);
      int      RecordSend(string   symbol,
                          int      cmd, 
                          double   volume, 
                          double   price, 
                          int      slippage, 
                          double   stoploss, 
                          double   takeprofit, 
                          int      magic=0, 
                          datetime expiration=0, 
                          color    arrow_color=clrNONE
                          );
      int      RecordsHistoryTotal(void);
      double   RecordStopLoss(void);
      int      RecordsTotal(void);
      double   RecordSwap(void);
      string   RecordSymbol(void);
      double   RecordTakeProfit(void);
      int      RecordTicket(void);
      int      RecordType(void);
      void     ResetLastErrorRecord(void);
      bool     Save(void);
      void     SetArrow(bool value);
      void     SetDebug(bool value);
      bool     SetMaxRecordCount(int value);
      void     SetRecordCount(int value);
      void     SetRecordFileName(string value);
      void     SetStatementFileName(string value);
      void     SetSelectElement(int value);
      void     SymbolToCharArray(string symbol, uchar& array[]);
      void     Tick(int shift=0);
      bool     WriteHTML(string file_name=NULL);
};


//----------------------------------------------------------------
// Check whether the open position has reached the settlement price.
// If it reaches the settlement price, execute RecordClose method.
//----------------------------------------------------------------
void ShadowRecord::CheckCloseRecords(const int shift=0)
{
   double ask, bid, point, spread;
   string symbol;
   
   RefreshRates();

   for(int i = 0; i < this.record_count; i++) {
      if(records[i].valid == false) continue;
      if(records[i].open == false) continue;
      
      symbol = CharArrayToString(records[i].symbol);
      
      if(records[i].cmd == 0) {
         if(shift == 0) {
            bid = MarketInfo(symbol, MODE_BID);
         } else {
            bid = iOpen(symbol, 0, shift);
         }
         
         if(records[i].stoploss > 0 && records[i].stoploss >= bid) {
            RecordClose(records[i].ticket, records[i].volume, bid, 0, clrNONE);
         }
         if(records[i].takeprofit > 0 && records[i].takeprofit <= bid) {
            RecordClose(records[i].ticket, records[i].volume, bid, 0, clrNONE);
         }
      }
      if(records[i].cmd == 1) {
         if(shift == 0) {
            ask = MarketInfo(symbol, MODE_ASK);
         } else {
            point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            spread = MarketInfo(symbol, MODE_SPREAD) * point;
            ask = iOpen(symbol, 0, shift) + spread;
         }
         
         if(records[i].stoploss > 0 && records[i].stoploss <= ask) {
            RecordClose(records[i].ticket, records[i].volume, ask, 0, clrNONE);
         }
         if(records[i].takeprofit > 0 && records[i].takeprofit >= ask) {
            RecordClose(records[i].ticket, records[i].volume, ask, 0, clrNONE);
         }
      }
   }
}


//----------------------------------------------------------------
// Confirm expiration date of pending order.
// If pending order expires, disable it.
//----------------------------------------------------------------
void ShadowRecord::CheckExpirationRecords(const int shift=0)
{
   datetime time = (shift == 0) ? TimeCurrent() : Time[shift];
   
   for(int i = 0; i < record_count; i++) {
      if(records[i].valid == false) continue;
      if(records[i].open == true) continue;
      
      // if pending order
      if(2 <= records[i].cmd && records[i].cmd <= 5) {
         if(records[i].expiration == 0) continue;
         if(records[i].expiration <= time) records[i].valid = false;
      }
   }
}


//----------------------------------------------------------------
// Check whether the pending order has reached the entry price.
// If the entry price has been reached, change the state.
//----------------------------------------------------------------
void ShadowRecord::CheckOpenRecords(const int shift=0)
{
   double   ask, bid;
   string   symbol;
   datetime time;
   
   RefreshRates();
   
   time = (shift == 0) ? TimeCurrent() : Time[shift];
   
   for(int i = 0; i < record_count; i++) {
      if(records[i].valid == false) continue;
      if(records[i].open == true) continue;
      
      symbol = CharArrayToString(records[i].symbol);
      
      // Buy Limit
      if(records[i].cmd == 2) {
         ask = MarketInfo(symbol, MODE_ASK);
         if(records[i].open_price >= ask) {
            records[i].open = true;
            records[i].cmd = 0;
            records[i].open_price = ask;
            records[i].open_time = time;
            records[i].expiration = 0;
         }
      }
      // Sell Limit
      else if(records[i].cmd == 3) {
         bid = MarketInfo(symbol, MODE_BID);
         if(records[i].open_price <= bid) {
            records[i].open = true;
            records[i].cmd = 1;
            records[i].open_price = bid;
            records[i].open_time = time;
            records[i].expiration = 0;
         }
      }
      // Buy Stop
      else if(records[i].cmd == 4) {
         ask = MarketInfo(symbol, MODE_ASK);
         if(records[i].open_price <= ask) {
            records[i].open = true;
            records[i].cmd = 0;
            records[i].open_price = ask;
            records[i].open_time = time;
            records[i].expiration = 0;
         }
      }
      // SellStop
      else if(records[i].cmd == 5) {
         bid = MarketInfo(symbol, MODE_BID);
         if(records[i].open_price >= bid) {
            records[i].open = true;
            records[i].cmd = 1;
            records[i].open_price = bid;
            records[i].open_time = time;
            records[i].expiration = 0;
         }
      }
   }
}


//----------------------------------------------------------------
//Returns element.
//----------------------------------------------------------------
int ShadowRecord::GetElement(const int ticket)
{
   for(int i = 0; i < record_count; i++) {
      if(records[i].ticket == ticket) return(i);
   }
   return(-1);
}


//----------------------------------------------------------------
// Create arrow object.
// TODO: check symbol
//----------------------------------------------------------------
void ShadowRecord::ArrowCreate(int id, int type, color arrow_color)
{
   int    arrow_code = 0;
   double price = 0;
   string object_name;
   
   if(Symbol() != CharArrayToString(records[id].symbol)) return;
   
   object_name = "Record" + IntegerToString(record_count);
   
   switch(type) {
      case 0:
         price = MarketInfo(Symbol(), MODE_ASK);
         arrow_code = 1;
         break;
      case 1:
         price = MarketInfo(Symbol(), MODE_BID);
         arrow_code = 1;
         break;
      case 2:
         price = MarketInfo(Symbol(), MODE_BID);
         arrow_code = 3;
         break;
      case 3:
         price = MarketInfo(Symbol(), MODE_ASK);
         arrow_code = 3;
         break;
      default: return; break;
   }
   
   ObjectCreate(0, object_name, OBJ_ARROW, 0, Time[0], price);
   ObjectSet(object_name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSet(object_name, OBJPROP_COLOR, arrow_color);
}


//----------------------------------------------------------------
// Delete arrow objects.
//----------------------------------------------------------------
void ShadowRecord::ArrowDelete(const int id)
{
   ObjectDelete(0, "Record" + IntegerToString(id));
}


//----------------------------------------------------------------
// Return total lots of the virtual open positions.
// If order type is buy, return positive number.
// If order type is sell, return negative number.
//----------------------------------------------------------------
double ShadowRecord::CurrentRecords(int type, string symbol, int magic)
{
   double lots = 0.0;

   for(int i = 0; i < RecordsTotal(); i++) {
      if(RecordSelect(i, SELECT_BY_POS) == false) break;
      if(RecordSymbol() != symbol || RecordMagicNumber() != magic) continue;

      switch(type) {
         case OP_BUY:
            if(RecordType() == OP_BUY) lots += RecordLots();
            break;
         case OP_SELL:
            if(RecordType() == OP_SELL) lots -= RecordLots();
            break;
         case OP_BUYLIMIT:
            if(RecordType() == OP_BUYLIMIT) lots += RecordLots();
            break;
         case OP_SELLLIMIT:
            if(RecordType() == OP_SELLLIMIT) lots -= RecordLots();
            break;
         case OP_BUYSTOP:
            if(RecordType() == OP_BUYSTOP) lots += RecordLots();
            break;
         case OP_SELLSTOP:
            if(RecordType() == OP_SELLSTOP) lots -= RecordLots();
            break;
         default:
            break;
      }
      if(lots != 0) break;
   }
   return(lots);
}


//----------------------------------------------------------------
// Record class deinitialization function.
//----------------------------------------------------------------
void ShadowRecord::Deinit()
{
   double   price;
   string   symbol;
   datetime time;
   
   time = TimeCurrent();
   
   for(int i = 0; i < record_count; i++) {
      if(records[i].valid == false) continue;
      if(records[i].open == false) continue;
      
      symbol = CharArrayToString(records[i].symbol);
      
      if(records[i].cmd == 0) {
         price = MarketInfo(symbol, MODE_BID);
      }
      else if(records[i].cmd == 1) {
         price = MarketInfo(symbol, MODE_ASK);
      }
      else {
         records[i].valid = false;
         continue;
      }
      
      records[i].open = false;
      records[i].close_time = time;
      records[i].close_price = price;
   }
   
   if(IsTesting()) WriteHTML(statement_file_name);
}


//----------------------------------------------------------------
// Returns Error Code.
//----------------------------------------------------------------
int ShadowRecord::GetLastErrorRecord()
{
   return(this.error_code);  
}


//----------------------------------------------------------------
// Returns Record_count.
//----------------------------------------------------------------
int ShadowRecord::GetMaxRecordCount()
{
   return(this.max_record_count);
}


//----------------------------------------------------------------
// Returns Record_count.
//----------------------------------------------------------------
int ShadowRecord::GetRecordCount()
{
   return(this.record_count);
}


//----------------------------------------------------------------
// Record class initialization function.
//----------------------------------------------------------------
void ShadowRecord::Init()
{
   record_count        = 0;
   select_element      = -1;
   max_record_count    = 30;
   show_arrow          = false;
   record_file_name    = "Record/" + MQLInfoString(MQL_PROGRAM_NAME)
                         + "/Record.bin";
   statement_file_name = "Record/" + MQLInfoString(MQL_PROGRAM_NAME)
                         + "/VirtualRecord.html";
}

//----------------------------------------------------------------
// Load records.
//----------------------------------------------------------------
bool ShadowRecord::Load(string file=NULL)
{
   int handle;
   
   if(file == NULL) file = record_file_name;
   handle = FileOpen(file, FILE_READ|FILE_BIN);
   
   if(handle != INVALID_HANDLE) {
      ArrayFree(records);
      record_count = 0;
      
      if(FileReadArray(handle, records, 0, WHOLE_ARRAY) <= 0) {
         Print("File read failed:", GetLastError());
         return(false);  
      }
      else {
         record_count = ArraySize(records);
      }
   }
   else {
      if(TerminalInfoString(TERMINAL_LANGUAGE) == "Japanese") {
         Print("ファイルが見つかりませんでした。");
      }
      else {
         Print("File open failed");
      }
      return(false);
   }
   return(true);
}


//----------------------------------------------------------------
// Convert period to string.
//----------------------------------------------------------------
string ShadowRecord::PeriodToString(int period)
{
   if(TerminalInfoString(TERMINAL_LANGUAGE) == "Japanese") {
      switch(period) {
         case PERIOD_M1:  return("1分足 (M1)");   break;
         case PERIOD_M5:  return("5分足 (M5)");   break;
         case PERIOD_M15: return("15分足 (M15)"); break;
         case PERIOD_M30: return("30分足 (M30)"); break;
         case PERIOD_H1:  return("1時間足 (H1)"); break;
         case PERIOD_H4:  return("4時間足 (H4)"); break;
         case PERIOD_D1:  return("日足 (D1)");    break;
         case PERIOD_W1:  return("週足 (W1)");    break;
         case PERIOD_MN1: return("月足 (MN1)");   break;
         default: break;
      }
   }
   else {
      switch(period) {
         case PERIOD_M1:  return("1 minute (M1)");    break;
         case PERIOD_M5:  return("5 minutes (M5)");   break;
         case PERIOD_M15: return("15 minutes (M15)"); break;
         case PERIOD_M30: return("30 minutes (M30)"); break;
         case PERIOD_H1:  return("1 hour (H1)");      break;
         case PERIOD_H4:  return("4 hours (H4)");     break;
         case PERIOD_D1:  return("1 day (D1)");       break;
         case PERIOD_W1:  return("1 week (W1)");      break;
         case PERIOD_MN1: return("1 month (MN1)");    break;
         default: break;
      }
   }
   
   return("");
}


//----------------------------------------------------------------
// Close opened Record.
//----------------------------------------------------------------
bool ShadowRecord::RecordClose(int    ticket, 
                               double lots, 
                               double price, 
                               int    slippage, 
                               color  arrow_color
                               )
{
   int      id, type = 0;
   double   ask, bid, min_lots, max_lots, lot_step;
   string   symbol;
   datetime time;
   
   RefreshRates();
   
   // check ticket
   id = GetElement(ticket);
   if(id < 0) {
      error_code = 4108; // invalid ticket
      return(false);
   }
   if(records[id].cmd != 0 && records[id].cmd != 1) {
      error_code = 4108; // invalid ticket
      return(false);
   }
   
   // check lots
   symbol = CharArrayToString(records[id].symbol);
   min_lots = MarketInfo(symbol, MODE_MINLOT);
   max_lots = MarketInfo(symbol, MODE_MAXLOT);
   lot_step = MarketInfo(symbol, MODE_LOTSTEP);
   
   if(lots < min_lots || lots > max_lots) {
      error_code = 131; // invalid trade volume
      return(false);
   }
   if(lots >= records[id].volume) lots = records[id].volume;
   
   // check price
   if(records[id].cmd == 0) {
      type = 2;
      bid = MarketInfo(symbol, MODE_BID);
      if(price > bid + slippage * SymbolInfoDouble(symbol, SYMBOL_POINT) || 
         price < bid - slippage * SymbolInfoDouble(symbol, SYMBOL_POINT)
         ) {
         error_code = 129; // invalid price
         return(false);
      }
   }
   else if(records[id].cmd == 1) {
      type = 3;
      ask = MarketInfo(symbol, MODE_ASK);
      if(price > ask + slippage * SymbolInfoDouble(symbol, SYMBOL_POINT) || 
         price < ask - slippage * SymbolInfoDouble(symbol, SYMBOL_POINT)
         ) {
         error_code = 129; // invalid price
         return(false);
      }
   }
   
   time = TimeCurrent();
   
   // full settlement
   if(lots >= records[id].volume) {
      records[id].open = false;
      records[id].close_time = time;
      records[id].close_price = price;
   }
   // partial settlement
   else {
      // create new Record
      records[record_count].valid = true;
      records[record_count].ticket = record_count + 1;
      records[record_count].open = true;
      records[record_count].open_time = records[id].open_time;
      records[record_count].close_time = 0;
      SymbolToCharArray(CharArrayToString(records[id].symbol), 
                        records[record_count].symbol
                        );
      records[record_count].cmd = records[id].cmd;
      records[record_count].volume = records[id].volume - lots;
      records[record_count].open_price = records[id].open_price;
      records[record_count].close_price = 0;
      records[record_count].stoploss = records[id].stoploss;
      records[record_count].takeprofit = records[id].takeprofit;
      records[record_count].magic = records[id].magic;
      records[record_count].expiration = 0;
      
      record_count++;
      
      // exit old record
      records[id].open = false;
      records[id].close_time = time;
      records[id].close_price = price;
      records[id].volume = lots;
   }
   
   if(show_arrow) ArrowCreate(record_count, type, arrow_color);
   
   return(true);
}


//----------------------------------------------------------------
// Returns close price of the currently selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordClosePrice()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false || 
      records[select_element].open == true
      ) {
      error_code = 4108; // invalid ticket
      return(0);
   }

   return(records[select_element].close_price);
}


//----------------------------------------------------------------
// Returns close time of the currently selcted Record.
//----------------------------------------------------------------
datetime ShadowRecord::RecordCloseTime()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false || 
      records[select_element].open == true
      ) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].close_time);
}


//----------------------------------------------------------------
// Returns calculated commissions of the currently selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordCommission()
{
   return(0);
}


//----------------------------------------------------------------
// Deletes previously opened pending Record.
//----------------------------------------------------------------
bool ShadowRecord::RecordDelete(int ticket, color arrow_color=clrNONE)
{
   int id;
   
   // check ticket
   id = GetElement(ticket);
   if(id == -1) {
      error_code = 4108; // invalid ticket
      return(false);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(NULL);
   }
   if(records[id].cmd != 0 && records[id].cmd != 1) {
      error_code = 4108; // invalid ticket
      return(false);
   }
   
   records[id].valid = false;
   
   return(true);
}


//----------------------------------------------------------------
// Returns expiration date of the selected pending Record.
//----------------------------------------------------------------
datetime ShadowRecord::RecordExpiration()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid != 2 && 
      records[select_element].valid != 3 && 
      records[select_element].valid != 4 && 
      records[select_element].valid != 5
      ) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].expiration);
}


//----------------------------------------------------------------
// Returns amount of lots of the selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordLots()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(0);
   }

   return(records[select_element].volume);
}


//----------------------------------------------------------------
// Returns an identifying (magic) number of the 
// currently selecteid record.
//----------------------------------------------------------------
int ShadowRecord::RecordMagicNumber()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(-1);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(-1);
   }

   return(records[select_element].magic);
   
}


//----------------------------------------------------------------
// Modification of characteristics of the 
// previously opened or pending records.
//----------------------------------------------------------------
bool ShadowRecord::RecordModify(int      ticket, 
                                double   price, 
                                double   stoploss, 
                                double   takeprofit, 
                                datetime expiration, 
                                color    arrow_color
                                )
{
   int      id, cmd;
   double   ask, bid, stoplevel;
   string   symbol;
   datetime time;
   
   RefreshRates();
   
   // check ticket
   id = GetElement(ticket);
   if(id == -1){
      error_code = 4108; // invalid ticket
      return(false);
   }
   
   // check price and expiration
   symbol    = CharArrayToString(records[id].symbol);
   cmd       = records[id].cmd;
   ask       = MarketInfo(symbol, MODE_ASK);
   bid       = MarketInfo(symbol, MODE_BID);
   stoplevel = MarketInfo(symbol, MODE_STOPLEVEL)
               * SymbolInfoDouble(symbol, SYMBOL_POINT);
   time      = TimeCurrent();
   
   switch(cmd) {
      // buy, sell
      case 0: case 1:
         break;
      case 2:
         if(price != 0 && price >= ask - stoplevel) {
            error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // sell limit
      case 3:
         if(price != 0 && price <= bid + stoplevel) {
            error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // buy stop
      case 4:
         if(price != 0 && price <= ask + stoplevel) {
            error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // sell stop
      case 5:
         if(price != 0 && price >= bid - stoplevel) {
            error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // unexpected value
      default:
         error_code = 4108; // invalid ticket
         return(false);
         break;
   }
   
   // check stoploss and takeprofit
   switch(cmd) {
      // buy
      case 0: case 2: case 4:
         if(stoploss != 0) {
            if(bid - stoplevel <= stoploss) {
               error_code = 130; // invalid stops
               return(false);
            }
            if(stoploss < 0) {
               error_code = 130; // invalid stops
               return(false);
            }
         }
         if(takeprofit != 0) {
            if(bid + stoplevel >= takeprofit) {
               error_code = 130; // invalid stops
               return(false);
            }
         }
         break;
      // sell
      case 1: case 3: case 5:
         if(stoploss != 0) {
            if(ask + stoplevel >= stoploss) {
               error_code = 130; // invalid stops
               return(false);
            }
         }
         if(takeprofit != 0) {
            if(ask - stoplevel <= takeprofit) {
               error_code = 130; // invalid stops
               return(false);
            }
            if(takeprofit < 0) {
               error_code = 130; // invalid stops
               return(false);
            }
         }
         break;
      default:
         error_code = 4108; // invalid ticket
         return(false);
         break;
   }
   
   // modification record
   if(cmd <= 2 && cmd >= 5 && price > 0) {
      records[id].open_price = price;
   }
   if(stoploss   != 0) records[id].stoploss   = stoploss;
   if(takeprofit != 0) records[id].takeprofit = takeprofit;
   if(expiration != 0) records[id].expiration = expiration;
   
   return(true);
}


//----------------------------------------------------------------
// Returns open price of the currently selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordOpenPrice()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].open_price);
}


//----------------------------------------------------------------
// Returns open time of the currently selected Record.
//----------------------------------------------------------------
datetime ShadowRecord::RecordOpenTime()
{
   if(select_element == -1) {
      error_code = 4108;//invalid ticket
      return(0);
   }
   if(records[select_element].valid == false) {
      error_code = 4108;//invalid ticket
      return(0);
   }

   return(records[select_element].open_time);
}


//----------------------------------------------------------------
// Returns profit of the currently selected order.
//----------------------------------------------------------------
double ShadowRecord::RecordProfit()
{
   string symbol;
   double profit, ask, bid;
   
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   symbol = CharArrayToString(records[select_element].symbol);
   
   if(records[select_element].open) {
      if(records[select_element].cmd == 0) {
         bid = MarketInfo(symbol, MODE_BID);
         profit = (bid - records[select_element].close_price) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * records[select_element].volume;
      }
      else if(records[select_element].cmd == 1) {
         ask = MarketInfo(symbol, MODE_ASK);
         profit = (records[select_element].open_price - ask) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * records[select_element].volume;
      }
      else {
         return(0);
      }
   }
   else {
      if(records[select_element].cmd == 0) {
         profit = (records[select_element].close_price 
                  - records[select_element].open_price) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * records[select_element].volume;
      }
      else if(records[select_element].cmd == 1) {
         profit = (records[select_element].open_price 
                  - records[select_element].close_price) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * records[select_element].volume;
      }
      else {
         return(0);
      }
   }
   
   return(profit);
}


//----------------------------------------------------------------
// The function selects an order for futher processing.
//----------------------------------------------------------------
bool ShadowRecord::RecordSelect(int index, int select, int pool=MODE_TRADES)
{
   int count = 0;
   
   //番号で選択
   if(select == SELECT_BY_POS) {
      //オープン・ポジションの場合
      if(pool == MODE_TRADES) {
         for(int i = 0; i < record_count; i++) {
            if(records[i].valid == false) continue;
            if(records[i].open == false) continue;
            if(index == count){
               select_element = i;
               return(true);
            }
            else count++;
         }
      }
      //ヒストリープールの場合
      else if(pool == MODE_HISTORY) {
         for(int i = 0; i < record_count; i++) {
            if(records[i].valid == false) continue;
            if(records[i].open == true) continue;
            if(index == count) {
               select_element = i;
               return(true);
            }
            else count++;
         }
      }
   }
   //チケット番号で選択
   else if(select == SELECT_BY_TICKET) {
      //オープン・ポジションの場合
      if(pool == MODE_TRADES) {
         for(int i = 0; i < record_count; i++) {
            if(records[i].valid == false) continue;
            if(records[i].open == false) continue;
            if(index == records[i].ticket) {
               select_element = i;
               return(true);
            }
         }
      }
      //ヒストリープールの場合
      else if(pool == MODE_HISTORY) {
         for(int i = 0; i < record_count; i++) {
            if(records[i].valid == false) continue;
            if(records[i].open == true) continue;
            if(index == records[i].ticket) {
               select_element = i;
               return(true);
            }
         }
      }
   }
   
   return(false);
}

//----------------------------------------------------------------
// The main function used to open or place a pending Record.
// Returns number of the ticket or -1 if it fails.
//----------------------------------------------------------------
int ShadowRecord::RecordSend(string   symbol, 
                             int      cmd, 
                             double   volume, 
                             double   price, 
                             int      slippage, 
                             double   stoploss, 
                             double   takeprofit, 
                             int      magic=0, 
                             datetime expiration=0, 
                             color    arrow_color=clrNONE)
{
   int      ticket = 0, type = 0;
   double   stoplevel, ask, bid, min_lots, max_lots;
   datetime time;
   
   RefreshRates();
   
   // check symbol
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT)) {
      error_code = 4106; // unknown symbol
      return(-1);
   }
   
   // check cmd, stoploss and takeprofit
   stoplevel = MarketInfo(symbol, MODE_STOPLEVEL) 
               * SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   switch(cmd) {
      // buy
      case 0: case 2: case 4:
         type = 0;
         if(stoploss != 0) {
            if(price - stoplevel <= stoploss) {
               error_code = 130; // invalid stops
               return(-1);
            }
            if(stoploss < 0) {
               error_code = 130; // invalid stops
               return(-1); 
            }
         }
         if(takeprofit != 0) {
            if(price + stoplevel >= takeprofit) {
               error_code = 130; // invalid stops
               return(-1);
            }
         }
         break;
      // sell
      case 1: case 3: case 5:
         type = 1;
         if(stoploss != 0) {
            if(price + stoplevel >= stoploss) {
               error_code = 130; // invalid stops
               return(-1);
            }
         }
         if(takeprofit != 0) {
            if(price - stoplevel <= takeprofit) {
               error_code = 130; // invalid stops
               return(-1);
            }
            if(takeprofit < 0) {
               error_code = 130; // invalid stops
               return(-1);
            }
         }
         break;
      default:
         error_code = 3; // invalid trade parameters
         return(-1);
         break;
   }
   
   // check volume
   min_lots = MarketInfo(symbol, MODE_MINLOT);
   max_lots = MarketInfo(symbol, MODE_MAXLOT);
   
   if(volume < min_lots || volume > max_lots) {
      error_code = 131; // invalid trade volume
      return(-1);
   }
   
   // check price and expiration
   ask = MarketInfo(symbol, MODE_ASK);
   bid = MarketInfo(symbol, MODE_BID);
   time = TimeCurrent();
   
   switch(cmd) {
      // buy, sell
      case 0: case 1: expiration = 0; break;
      case 2:
         if(stoplevel != 0) {
            if(price >= ask - stoplevel) {
               error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // sell limit
      case 3:
         if(stoplevel != 0) {
            if(price <= bid + stoplevel) {
               error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // buy stop
      case 4:
         if(stoplevel != 0) {
            if(price <= ask + stoplevel) {
               error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // sell stop
      case 5:
         if(stoplevel != 0) {
            if(price >= bid - stoplevel) {
               error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // unexpected value
      default:
         error_code = 3; // invalid trade parameters
         return(-1);
         break;
   }
   
   ArrayResize(records, record_count+1);
   
   // create record
   ticket = record_count + 1;
   
   records[record_count].valid = true;
   records[record_count].ticket = ticket;
   if(cmd == 0 || cmd == 1) records[record_count].open = true;
   else records[record_count].open = false;
   records[record_count].open_time = time;
   records[record_count].close_time = 0;
   SymbolToCharArray(symbol, records[record_count].symbol);
   records[record_count].cmd = cmd;
   records[record_count].volume = volume;
   records[record_count].open_price = price;
   records[record_count].close_price = 0;
   records[record_count].stoploss = stoploss;
   records[record_count].takeprofit = takeprofit;
   records[record_count].magic = magic;
   if(expiration > 0) {
      records[record_count].expiration = time + expiration * 1000;
   }
   else {
      records[record_count].expiration = 0;
   }
   
   if(show_arrow) ArrowCreate(record_count, type, arrow_color);
   
   record_count++;
   
   return(ticket);
}


//----------------------------------------------------------------
// Returns the number of closed Records in the account history 
// loaded into the Record class.
//----------------------------------------------------------------
int ShadowRecord::RecordsHistoryTotal()
{
   int count = 0;
   
   for(int i = 0; i < record_count; i++) {
      if(records[i].valid == false) continue;
      if(records[i].open == false) count++;
   }
   
   return(count);
}


//----------------------------------------------------------------
// Returns stop loss value of the currently selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordStopLoss()
{
   if(select_element == -1) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false) {
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].stoploss);
}


//----------------------------------------------------------------
// Returns the number of market and pending Records.
//----------------------------------------------------------------
int ShadowRecord::RecordsTotal()
{
   int count = 0;
   
   for(int i = 0; i < record_count; i++) {
      if(records[i].valid == false) continue;
      if(records[i].open == true) count++;
   }
   
   return(count);
}


//----------------------------------------------------------------
// Returns swap value of the currently selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordSwap()
{
   return(0);
}


//----------------------------------------------------------------
// Returns symbol name of the currently selected Record.
//----------------------------------------------------------------
string ShadowRecord::RecordSymbol()
{
   if(select_element == -1){
      error_code = 4108; // invalid ticket
      return(NULL);
   }
   if(records[select_element].valid == false){
      error_code = 4108; // invalid ticket
      return(NULL);
   }
   
   return(CharArrayToString(records[select_element].symbol));
}


//----------------------------------------------------------------
// Returns take profit value of the currently selected Record.
//----------------------------------------------------------------
double ShadowRecord::RecordTakeProfit()
{
   if(select_element == -1){
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false){
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].takeprofit);
}


//----------------------------------------------------------------
// Returns ticket number of the currently selectted Record.
//----------------------------------------------------------------
int ShadowRecord::RecordTicket()
{
   if(select_element == -1){
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false){
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].ticket);
}


//----------------------------------------------------------------
// Returns Record operation type of the currently selected Record.
//----------------------------------------------------------------
int ShadowRecord::RecordType()
{
   if(select_element == -1){
      error_code = 4108; // invalid ticket
      return(0);
   }
   if(records[select_element].valid == false){
      error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(records[select_element].cmd);
}


//----------------------------------------------------------------
// Sets the value of the variable error_code into zero.
//----------------------------------------------------------------
void ShadowRecord::ResetLastErrorRecord()
{
   error_code = 0;
}


//----------------------------------------------------------------
// Save records
//----------------------------------------------------------------
bool ShadowRecord::Save()
{
   int handle;
   
   handle = FileOpen(record_file_name, FILE_READ|FILE_WRITE|FILE_BIN);
   
   if(handle != INVALID_HANDLE){
      FileSeek(handle, 0, SEEK_SET);
      if(FileWriteArray(handle, records, 0, ArrayRange(records, 0)) == 0){
         Print(__FUNCTION__, 
               " Failed to save the file, error:", 
               GetLastError()
               );
         FileClose(handle);
         return(false);
      }
      FileClose(handle);
   }
   else {
      Print(__FUNCTION__, " Failed to open the file, error ", GetLastError());
      return(false);
   }
   
   return(true);
}


//----------------------------------------------------------------
// Sets the value of the variable show_arrow into input argument.
//----------------------------------------------------------------
void ShadowRecord::SetArrow(bool value)
{
   show_arrow = value;
}


//----------------------------------------------------------------
// Sets the value of the variable max_record_count into input argument.
//----------------------------------------------------------------
bool ShadowRecord::SetMaxRecordCount(int value)
{
   if(value > 0){
      max_record_count = value;
      ArrayResize(records, max_record_count, 0);
      return(true);
   }
   return(false);
}


//----------------------------------------------------------------
// Sets the value of the variable record_count into input argument.
//----------------------------------------------------------------
void ShadowRecord::SetRecordCount(int value)
{
   record_count = value;
}


//----------------------------------------------------------------
// Sets the value of the variable record_file_name into input argument.
//----------------------------------------------------------------
void ShadowRecord::SetRecordFileName(string value)
{
   record_file_name = value;
}


//----------------------------------------------------------------
// Sets the value of the variable StatementFileName into input argument.
//----------------------------------------------------------------
void ShadowRecord::SetStatementFileName(string value)
{
   statement_file_name = value;
}


//----------------------------------------------------------------
// Sets the value of the variable select_element into input argument.
//----------------------------------------------------------------
void ShadowRecord::SetSelectElement(int value)
{
   select_element = value;
}


//----------------------------------------------------------------
// Convert symbol(string type) to char array.
//----------------------------------------------------------------
void ShadowRecord::SymbolToCharArray(string symbol, uchar& array[])
{
   StringToCharArray(symbol, array, 0, WHOLE_ARRAY, CP_ACP);
}


//----------------------------------------------------------------
// tick function.
//----------------------------------------------------------------
void ShadowRecord::Tick(int shift=0)
{
   error_code = 0;
   select_element = -1;
   CheckExpirationRecords(shift);
   CheckOpenRecords(shift);
   CheckCloseRecords(shift);
}


//----------------------------------------------------------------
// Create HTML file.
//----------------------------------------------------------------
bool ShadowRecord::WriteHTML(string file_name=NULL)
{
   // local variables
   int count                = 0;
   int type                 = -1;
   int digits               = 2;
   int TotalTrades          = 0;
   int ProfitCount          = 0; 
   int LossCount            = 0;
   int LongPositions        = 0;
   int ShortPositions       = 0;
   int LongWonCount         = 0; 
   int ShortWonCount        = 0;
   int ConsecutiveWins      = 0;
   int MaxConsecutiveWins   = 0; 
   int ConsecutiveLosses    = 0;
   int MaxConsecutiveLosses = 0;
   
   uint start_time;
   
   double balance                = 10000;
   double pf                     = 0;
   double payoff                 = 0;
   double avg_profit_trade       = 0;
   double avg_loss_trade         = 0;
   double TotalProfit            = 0;
   double GrossProfit            = 0;
   double GrossLoss              = 0;
   double MaxProfit              = 0;
   double MinLoss                = 0;
   double ConsecutiveProfit      = 0;
   double ConsecutiveLoss        = 0;
   double MaxConsecutiveProfit   = 0;
   double MinConsecutiveLoss     = 0;
   double LongWinningPercentage  = 0;
   double ShortWinningPercentage = 0;
   double WinningPercentage      = 0;
   double LosingPercentage       = 0;
   
   string out, trade;
                 
   if(file_name == NULL) {
      file_name = "Record/" + MQLInfoString(MQL_PROGRAM_NAME) 
                  + "/VirtualRecord.html";
   }
   
   // open
   int handle = FileOpen(file_name, FILE_TXT|FILE_WRITE);
   if(handle < 0) {
      Print(__FUNCTION__, ": output file creation error!!");
      return(false);
   }
   FileSeek(handle, 0, SEEK_SET);
   
   // display progress
   start_time = GetTickCount();
   
   // create ducument
   if(AccountCurrency() == "JPY") balance = 1000000;
   if(IsTesting()) balance = AccountBalance() - TesterStatistics(STAT_PROFIT);
   
   for(int i = 0; i < RecordsHistoryTotal(); i++) {
      if(!RecordSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      
      // display progress every 10 minutes.
      if(GetTickCount() > start_time + 10 * 1000) {
         Print(__FUNCTION__, " :", (i+1), "/", RecordsHistoryTotal());
         Comment((i+1), "/", RecordsHistoryTotal());
         start_time = GetTickCount();
      }
      
      digits = (int)MarketInfo(RecordSymbol(), MODE_DIGITS);
      count++;
      
      // record when entry
      trade += "<tr align=right>";
      trade += "<td>" + IntegerToString(count) + "</td>";
      trade += "<td class=msdate>";
      trade += TimeToString(RecordOpenTime(), TIME_DATE|TIME_MINUTES);
      trade += "</td>";
      type = RecordType();
      switch(type) {
         case 0:  trade += "<td>buy</td>";        break;
         case 1:  trade += "<td>sell</td>";       break;
         case 2:  trade += "<td>buy limit</td>";  break;
         case 3:  trade += "<td>sell limit</td>"; break;
         case 4:  trade += "<td>buy stop</td>";   break;
         case 5:  trade += "<td>sell stop</td>";  break;
         default: trade += "<td></td>";           break;
      }
      trade += "<td>" + IntegerToString(RecordTicket()) + "</td>";
      trade += "<td class=mspt>" + DoubleToString(RecordLots(), 2) + "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\">";
      trade += DoubleToString(RecordOpenPrice(), digits) + "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(RecordStopLoss(), digits) + "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(RecordTakeProfit(), digits) + "</td>";
      trade += "<td colspan=2></td>";
      trade += "</tr>";
      trade += "\n";
      
      count++;
      
      // record when exit
      trade += "<tr bgcolor=\"#E0E0E0\" align=right>";
      trade += "<td>" + IntegerToString(count) + "</td>";
      trade += "<td class=msdate>" ;
      trade += TimeToString(RecordCloseTime(), TIME_DATE|TIME_MINUTES);
      trade += "</td>";
      trade += "<td>close</td>";
      trade += "<td>" + IntegerToString(RecordTicket()) + "</td>";
      trade += "<td class=mspt>" + DoubleToString(RecordLots(), 2) + "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" >";
      trade += DoubleToString(RecordClosePrice(), digits);
      trade += "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(RecordStopLoss(), digits);
      trade += "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(RecordTakeProfit(), digits);
      trade += "</td>";
      trade += "<td class=mspt>" + DoubleToString(RecordProfit(), 2) + "</td>";
      TotalProfit += NormalizeDouble(RecordProfit(), 2);
      trade += "<td class=mspt>";
      trade += DoubleToString((balance + TotalProfit), 2);
      trade += "</td>";
      trade += "</tr>";
      trade += "\n";
      
      // aggregation processing
      if(RecordProfit() > 0) {
         GrossProfit += RecordProfit();
         ProfitCount++;
         if(RecordType() == 0) {
            LongPositions++;
            LongWonCount++;
         }
         if(RecordType() == 1) {
            ShortPositions++;
            ShortWonCount++;
         }
         if(RecordProfit() > MaxProfit) MaxProfit = RecordProfit();
         ConsecutiveWins++;
         ConsecutiveLosses = 0;
         ConsecutiveProfit += RecordProfit();
         ConsecutiveLoss = 0;
         if(ConsecutiveWins > MaxConsecutiveWins) {
            MaxConsecutiveWins = ConsecutiveWins;
         }
         if(ConsecutiveProfit > MaxConsecutiveProfit) {
            MaxConsecutiveProfit = ConsecutiveProfit;
         }
      }
      if(RecordProfit() < 0) {
         GrossLoss += RecordProfit();
         LossCount++;
         if(RecordType() == 0) LongPositions++;
         if(RecordType() == 1) ShortPositions++;
         if(RecordProfit() < MinLoss) MinLoss = RecordProfit();
         ConsecutiveWins = 0;
         ConsecutiveLosses++;
         ConsecutiveProfit = 0;
         ConsecutiveLoss += RecordProfit();
         if(ConsecutiveLosses > MaxConsecutiveLosses) {
            MaxConsecutiveLosses = ConsecutiveLosses;
         }
         if(ConsecutiveLoss < MinConsecutiveLoss) {
            MinConsecutiveLoss = ConsecutiveLoss;
         }
      }
      TotalTrades++;
      
   }
   
   if(AccountCurrency() == "JPY") digits = 0;
   else digits = 2;
   
   out =  "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"";
   out += " \"http://www.w3.org/TR/html4/strict.dtd\">\n";
   out += "<html>\n";
   out += "  <head>\n";
   out += "     <title>Virtual Record: "; 
   out += MQLInfoString(MQL_PROGRAM_NAME);
   out += "</title>\n";
   out += "     <meta name=\"version\" content=\"Build ";
   out += IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)) + "\">\n";
   out += "     <meta name=\"server\" content=\"" + AccountServer() + "\">\n";
   out += "     <style type=\"text/css\" media=\"screen\">\n";
   out += "     <!--\n";
   out += "     td { font: 8pt Tahoma,Arial; }\n";
   out += "     //-->\n";
   out += "     </style>\n";
   out += "     <style type=\"text/css\" media=\"print\">\n";
   out += "     <!--\n";
   out += "     td { font: 7pt Tahoma,Arial; }\n";
   out += "     //-->\n";
   out += "     </style>\n";
   out += "     <style type=\"text/css\">\n";
   out += "     <!--\n";
   out += "     .msdate { mso-number-format:\"General Date\"; }\n";
   out += "     .mspt   { mso-number-format:\\#\\,\\#\\#0\\.00;  }\n";
   out += "     //-->\n";
   out += "     </style>\n";
   out += "  </head>\n";
   out += "<body topmargin=1 marginheight=1>\n";
   out += "<div align=center>\n";
   out += "<div style=\"font: 20pt Times New Roman\">";
   out += "<b>Virtual Record Report</b>";
   out += "</div>\n";
   out += "<div style=\"font: 16pt Times New Roman\">";
   out += "<b>" + MQLInfoString(MQL_PROGRAM_NAME) + "</b>";
   out += "</div>\n";
   out += "<div style=\"font: 10pt Times New Roman\">";
   out += "<b>" + AccountServer() + " (Build ";
   out += IntegerToString(TerminalInfoInteger(TERMINAL_BUILD));
   out += ")</b>";
   out += "</div><br>\n";
   
   out += "<table width=820 cellspacing=1 cellpadding=3 border=0>\n";
   out += "<tr align=left>";
   out += "<td colspan=2>通貨ペア</td>";
   out += "<td colspan=4>" + Symbol() + "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2>期間</td>";
   out += "<td colspan=4>" + PeriodToString(Period()) + "</td>";
   out += "</tr>\n";
   out += "<tr height=8><td colspan=6></td></tr>\n";
   out += "<tr align=left>";
   out += "<td>初期証拠金</td><td align=right>";
   out += DoubleToString(balance, digits);
   out += "</td>";
   out += "<td></td><td align=right></td>";
   out += "<td>スプレッド</td><td align=right>";
   out += IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD));
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td>総損益</td><td align=right>";
   out += DoubleToString(TotalProfit, digits);
   out += "</td>";
   out += "<td>総利益</td><td align=right>";
   out += DoubleToString(GrossProfit, digits);
   out += "</td>";
   out += "<td>総損失</td><td align=right>";
   out += DoubleToString(GrossLoss, digits);
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   if(GrossLoss != 0) pf = GrossProfit / MathAbs(GrossLoss);
   out += "<td>プロフィットファクター</td>";
   out += "<td align=right>" + DoubleToString(pf, digits) + "</td>";
   if(TotalTrades > 0) payoff = TotalProfit / TotalTrades;
   out += "<td>期待利得</td>";
   out += "<td align=right>" + DoubleToString(payoff, digits) + "</td>";
   out += "<td></td><td align=right></td>";
   out += "</tr>\n";
   out += "<tr height=8><td colspan=6></td></tr>\n";
   out += "<tr align=left>";
   out += "<td>総取引数</td>";
   out += "<td align=right>" + IntegerToString(TotalTrades) + "</td>";
   if(LongPositions > 0) {
      LongWinningPercentage = (double)LongWonCount 
                              / (double)LongPositions 
                              * 100;
   }
   if(ShortPositions > 0) {
      ShortWinningPercentage = (double)ShortWonCount 
                               / (double)ShortPositions 
                               * 100;
   }
   out += "<td>ショートポジション(勝率%）</td>";
   out += "<td align=right>";
   out += IntegerToString(ShortPositions);
   out += " (" + DoubleToString(ShortWinningPercentage, digits) + "%)";
   out += "</td>";
   out += "<td>ロングポジション(勝率%）</td>";
   out += "<td align=right>";
   out += IntegerToString(LongPositions);
   out += " (" + DoubleToString(LongWinningPercentage, digits) + "%)";
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right></td>";
   if(TotalTrades > 0) {
      WinningPercentage = (double)ProfitCount / (double)TotalTrades * 100;
      LosingPercentage = (double)LossCount / (double)TotalTrades * 100;
   }
   out += "<td>勝率(%)</td><td align=right>";
   out += IntegerToString(ProfitCount);
   out += " (" + DoubleToString(WinningPercentage, digits) + "%)";
   out += "</td>";
   out += "<td>負率(%)</td>";
   out += "<td align=right>";
   out += IntegerToString(LossCount);
   out += " (" + DoubleToString(LosingPercentage, digits) + "%)";
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right>最大</td>";
   out += "<td>勝トレード</td><td align=right>";
   out += DoubleToString(MaxProfit, digits);
   out += "</td>";
   out += "<td>負トレード</td><td align=right>";
   out += DoubleToString(MinLoss, digits);
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right>平均</td>";
   if(ProfitCount > 0) avg_profit_trade = GrossProfit / ProfitCount * 100;
   out += "<td>勝トレード</td><td align=right>";
   out += DoubleToString(avg_profit_trade, digits);
   out += "</td>";
   if(LossCount > 0) avg_loss_trade = GrossLoss / LossCount * 100;
   out += "<td>負トレード</td><td align=right>";
   out += DoubleToString(avg_loss_trade, digits);
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right>最大</td>";
   out += "<td>連勝(金額)</td><td align=right>";
   out += IntegerToString(MaxConsecutiveWins);
   out += " (" + DoubleToString(MaxConsecutiveProfit, digits) + ")";
   out += "</td>";
   out += "<td>連敗(金額)</td><td align=right>";
   out += IntegerToString(MaxConsecutiveLosses);
   out += " (" + DoubleToString(MinConsecutiveLoss, digits) + ")";
   out += "</td>";
   out += "</tr>\n";
   out += "</table>\n";
   out += "<br>\n";

   out += "<table width=820 cellspacing=1 cellpadding=3 border=0>\n";
   out += "<tr bgcolor=\"#C0C0C0\" align=right>";
   out += "<td>#</td><td>時間</td><td>取引種別</td><td>注文番号</td>";
   out += "<td>数量</td><td>価格</td><td>SL</td>";
   out += "<td>TP</td><td>損益</td><td>残高</td>";
   out += "</tr>\n";
   out += trade;
   out += "</table>\n";
   out += "</div></body></html>";
   
   FileWriteString(handle, out);
   if(0 < handle) FileClose(handle);
   
   return(true);
}


#endif
