@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Booking CDS Entity as first child'
@Metadata.ignorePropagatedAnnotations: true
@VDM.viewType: #COMPOSITE
define view entity ZRAP_KK_BOOKING
  as select from /dmo/booking_m
  composition[0..*] of ZRAP_KK_BOOKSUPPL as _BookingSuppl
  association        to parent ZRAP_KK_TRAVEL        as _Travel        on  $projection.TravelId = _Travel.TravelId
  association of one to one /DMO/I_Customer          as _Customer      on  $projection.CustomerId = _Customer.CustomerID
  association of one to one /DMO/I_Carrier           as _Carrier       on  $projection.CarrierId = _Carrier.AirlineID
  association of one to one /DMO/I_Connection        as _Connection    on  $projection.CarrierId    = _Connection.AirlineID
                                                                       and $projection.ConnectionId = _Connection.ConnectionID
  association of one to one /DMO/I_Booking_Status_VH as _BookingStatus on  $projection.BookingStatus = _BookingStatus.BookingStatus

{
  key travel_id       as TravelId,
  key booking_id      as BookingId,
      booking_date    as BookingDate,
      customer_id     as CustomerId,
      carrier_id      as CarrierId,
      connection_id   as ConnectionId,
      flight_date     as FlightDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      flight_price    as FlightPrice,
      currency_code   as CurrencyCode,
      booking_status  as BookingStatus,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,
      _Customer,
      _Carrier,
      _Connection,
      _BookingStatus,
      _Travel,
      _BookingSuppl
}
