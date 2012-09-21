function RootCtrl($scope, syncedModel) {
  $scope.model = syncedModel.model;
  $scope.connected = syncedModel.connected;
}
