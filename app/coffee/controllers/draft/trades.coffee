class TradesController extends BaseController
  @register 'TradesController'
  @inject '$scope',
  '$rootScope',
  '$routeParams',
  'subscriptionKeys',
  'api',
  'messageService'

  initialize: ->
    @currentDraftCounter = 0

    @deregister = @$scope.$on @subscriptionKeys.loadDraftDependentData, (event, args) =>
      @draftCounterChanged = if args.onPageLoad? and args.onPageLoad then true else @currentDraftCounter != args.draft.draft_counter
      @currentDraftCounter = if args.draft? then args.draft.draft_counter else 0

      if args.draft? and args.draft.setting_up == true
        @$scope.pageError = true
        @sendToPreviousPath()
        @messageService.showWarning "Draft is still setting up"
        @deregister()
      else if args.draft? and (args.draft.in_progress == true || args.draft.complete == true)
        if @draftCounterChanged
          @_loadTradeData(args.draft.draft_id, args)

    @$scope.$on @subscriptionKeys.scopeDestroy, (event, args) =>
      @deregister()

  _loadTradeData: (draft_id, args) =>
    tradesSuccess = (data) =>
      @$scope.tradesLoading = false
      @$scope.trades = data

      for trade in @$scope.trades
        trade.trade_time = new Date(trade.trade_time)

    errorHandler = (data) =>
      @$scope.tradesLoading = false
      @$scope.tradesError = true

    @$scope.tradesLoading = args.onPageLoad? and args.onPageLoad
    @$scope.tradesError = false

    if @$scope.draftValid and not @$scope.draftLocked
      tradesPromise = @api.Trade.query({ draft_id: draft_id }, tradesSuccess, errorHandler)