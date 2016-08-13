class CommishPickEditController extends AngularController
  @register 'CommishPickEditController'
  @$inject: ["$scope", "$routeParams", "messageService", "pickService", "api", "limitToFilter", "subscriptionKeys"]
  @inject: (args...) ->
      args.push '$scope'
      args.push '$routeParams'
      args.push 'messageService'
      args.push 'pickService'
      args.push 'api'
      args.push 'limitToFilter'
      args.push 'subscriptionKeys'
      super args...

  constructor: ->
    super(arguments...)

    @initialize?()

  initialize: ->
    #Passed in
    #@$scope.manualEntry = false
    #@$scope.playerSearchLoading = false
    @$scope.currentLoading = false

    #If manual entry, we need to make sure to properly update "selected" on the current pick so the display acts accordingly
    @$scope.$watch ( =>
      @$scope.currentPick
    ), =>
      @$scope.isFirstPick = @$scope.currentPick?.player_pick == '1'

      if @$scope.manualEntry
        #If we have a first AND last name, go ahead and show this as a pick. May not have position coloring, but thats OK.
        hasFirst = @$scope.currentPick.first_name? and @$scope.currentPick.first_name.length > 0
        hasLast = @$scope.currentPick.last_name? and @$scope.currentPick.last_name.length > 0
        hasTeam = @$scope.currentPick.team? and @$scope.currentPick.team.length > 0
        hasPosition = @$scope.currentPick.position? and @$scope.currentPick.position.length > 0

        @$scope.currentPick.selected = hasFirst or hasLast or hasTeam or hasPosition
    , true

  buttonClicked: =>
    if not @formIsInvalid()
      @_add()

  formIsInvalid: =>
    return @$scope.editInProgress or not @form.$valid

  _add: ->
    @$scope.editInProgress = true

    #If the user has chosen to perform manual entry, we just automatically run the check again,
    #For edit contexts, if its the same player, just let it go thru.
    if @$scope.manualEntry and not @_pickIsTheSame()
      duplicateCheckSuccess = (response) =>
        if response.pickIsNotDuplicate == false
          @wipePick()
          @$scope.editInProgress = false
          @messageService.showInfo "Pick was reset - go ahead and enter another player."
        else
          @$scope.pickAction?()

      duplicateCheckFailure = (response) =>
        @$scope.editInProgress = false
        @messageService.showError "Unable to enter pick - error while checking for duplicates."

      duplicateResult = @pickService.checkForExistingPicks(@$routeParams.draft_id, @$scope.currentPick)

      duplicateResult.promise.then duplicateCheckSuccess, duplicateCheckFailure
    else
      @$scope.pickAction?()

  proPlayerSearch: (searchTerm) ->
    @api.Pick.searchProPlayers({league: @$scope.draft.draft_sport, searchTerm: searchTerm}).$promise.then (data) =>
      return @limitToFilter(data.players, 10)
    .catch =>
      @messageService.closeToasts()
      @messageService.showError "Unable to search pro players"

  selectPlayer: (item, model, label) ->
    item.selected = true
    #Want to keep data about pick (round, pick #) as well as add player name, position, team, so merge not assignment:
    @$scope.currentPick = angular.merge({}, @$scope.currentPick, item)
    delete @$scope.playerSearch
    @$scope.playerSearch = ''

    #For edit contexts, if its the same player, just let it go thru.
    #Potentially fixes #12: https://github.com/mattheworres/phpdraft/issues/12
    #Ensure that the current pick is not in the process of being loaded.
    #Select player may be getting erroneously fired while the current pick is being reloaded.
    if not @_pickIsTheSame() and not @$scope.currentLoading
      #Perform an eager API call to ensure autocomplete player is not a duplicate
      duplicateCheckSuccess = (response) =>
        #If there were matches and the user wanted to wipe the pick, then do that. Otherwise, do nothing
        if response.pickIsNotDuplicate == false
          @wipePick()
          @messageService.showInfo "Pick was reset - go ahead and enter another player."

      duplicateCheckFailure = (response) =>
        @addInProgress = false
        @messageService.showError "Unable to select pick - error while checking for duplicates."
        @wipePick()

      duplicateResult = @pickService.checkForExistingPicks(@$routeParams.draft_id, @$scope.currentPick)

      duplicateResult.promise.then duplicateCheckSuccess, duplicateCheckFailure

  wipePick: ->
    @$scope.manualEntry = false
    @$scope.currentPick = @$scope.pristinePick

  _pickIsTheSame: ->
    firstIsSame = @$scope.currentPick.first_name == @$scope.pristinePick.first_name
    lastIsSame = @$scope.currentPick.last_name == @$scope.pristinePick.last_name
    teamIsSame = @$scope.currentPick.team == @$scope.pristinePick.team
    positionIsSame = @$scope.currentPick.position == @$scope.pristinePick.position

    firstIsSame and lastIsSame and teamIsSame and positionIsSame