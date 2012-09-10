function StatusCtrl($scope, syncService) {
  $scope.nsyncs = 0;
  $scope.state = null;

  syncService.subscribe('/sync/global', function(data) {
    $scope.nsyncs++;
    $scope.state = data;
    console.log("statusctrl got message ", data);
  })
}

function SettingsCtrl($scope, syncService) {
  $scope.nsyncs = 0;
  $scope.state = null;

  syncService.subscribe('/sync/settings', function(data) {
    $scope.nsyncs++;
    $scope.state = data;
  })
}

function RosterCtrl($scope, syncService) {
  $scope.nsyncs = 0;
  $scope.state = null;

  syncService.subscribe('/sync/roster', function(data) {
    $scope.nsyncs++;
    $scope.state = data;
  })
}