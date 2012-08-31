function StatusCtrl($scope, syncService) {

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