@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Booking Supplement Child entity'
@Metadata.ignorePropagatedAnnotations: true
@VDM.viewType: #COMPOSITE
define view entity ZRAP_KK_BOOKSUPPL as select from /dmo/booksuppl_m
association to parent ZRAP_KK_BOOKING as _Booking
    on $projection.TravelId = _Booking.TravelId
    and $projection.BookingId = _Booking.BookingId
association[1..1] to ZRAP_KK_TRAVEL as _Travel on $projection.TravelId = _Travel.TravelId
association[1..1] to /DMO/I_Supplement as _Supplement on $projection.SupplementId = _Supplement.SupplementID
association[1..*] to /DMO/I_SupplementText as _SupplmentText on $projection.SupplementId = _SupplmentText.SupplementID
{
    key travel_id as TravelId,
    key booking_id as BookingId,
    key booking_supplement_id as BookingSupplementId,
    supplement_id as SupplementId,
    @Semantics.amount.currencyCode: 'CurrencyCode'
    price as Price,
    currency_code as CurrencyCode,
    @Semantics.systemDateTime.lastChangedAt: true
    last_changed_at as LastChangedAt,
    _Travel,
    _Booking,
    _Supplement,
    _SupplmentText    
}
