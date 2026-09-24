@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Book Supplement Processor Projection Entity'
@Metadata.ignorePropagatedAnnotations: false
@VDM.viewType: #CONSUMPTION
define view entity ZRAP_KK_BOOKSUPPL_PROCESSOR as projection on ZRAP_KK_BOOKSUPPL
{
    key TravelId,
    key BookingId,
    key BookingSupplementId,
    SupplementId,
    Price,
    CurrencyCode,
    LastChangedAt,
    /* Associations */
    _Booking : redirected to parent ZRAP_KK_BOOKING_PROCESSOR,
    _Supplement,
    _SupplmentText,
    _Travel : redirected to ZRAP_KK_TRAVEL_PROCESSOR
}
