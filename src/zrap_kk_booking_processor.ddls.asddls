@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Booking Processor Projection entity'
@Metadata.ignorePropagatedAnnotations: false
@VDM.viewType: #CONSUMPTION
define view entity ZRAP_KK_BOOKING_PROCESSOR as projection on ZRAP_KK_BOOKING
{
    key TravelId,
    key BookingId,
    BookingDate,
    CustomerId,
    CarrierId,
    ConnectionId,
    FlightDate,
    FlightPrice,
    CurrencyCode,
    BookingStatus,
    LastChangedAt,
    /* Associations */
    _BookingStatus,
    _BookingSuppl : redirected to composition child ZRAP_KK_BOOKSUPPL_PROCESSOR,
    _Carrier,
    _Connection,
    _Customer,
    _Travel : redirected to parent ZRAP_KK_TRAVEL_PROCESSOR
}
