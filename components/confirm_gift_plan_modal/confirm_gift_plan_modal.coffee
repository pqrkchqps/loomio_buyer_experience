angular.module('loomioApp').factory 'ConfirmGiftPlanModal', ->
  templateUrl: 'generated/components/confirm_gift_plan_modal/confirm_gift_plan_modal.html'
  size: 'confirm-gift-plan-modal'
  controller: ($scope, group, ModalService, ChoosePlanModal, GroupWelcomeModal) ->
    $scope.group = group

    $scope.choosePlan = ->
      ModalService.open ChoosePlanModal, group: -> $scope.group

    $scope.submit = ->
      $scope.group.remote.postMember(group.key, 'use_gift_subscription').then ->
        ModalService.open GroupWelcomeModal, group: -> $scope.group
        $scope.$close()
