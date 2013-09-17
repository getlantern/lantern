$.waypoints.settings.scrollThrottle = 10
$.waypoints.settings.resizeThrottle = 20
standardWait = 50

describe 'Waypoints Infinite Scroll Shortcut', ->
  $items = $container = $more = beforeHit = afterHit = null
  $win = $ window

  beforeEach ->
    loadFixtures 'infinite.html'
    $items = $ '.infinite-item'
    $container = $ '.infinite-container'
    $more = $ '.infinite-more-link'
    beforeHit = afterHit = false

  it 'returns the same jQuery object for chaining', ->
    expect($items.waypoint('infinite').get()).toEqual $items.get()

  describe 'loading new pages', ->
    beforeEach ->
      options =
        onBeforePageLoad: -> beforeHit = true
        onAfterPageLoad: -> afterHit = true
      $container.waypoint 'infinite', options
      runs ->
        scrollVal = $.waypoints('viewportHeight') - $container.height()
        $win.scrollTop scrollVal
      done = -> $('.infinite-item').length > $items.length
      waitsFor done, 2000, 'new items to load'

    it 'appends them to the infinite container', ->
      expect($('.infinite-container > .infinite-item').length).toEqual 10
    
    it 'replaces the more link with the new more link', ->
      expect($more[0]).not.toEqual $('.infinite-more-link')[0]
      expect($('.infinite-more-link').length).toEqual 1

    it 'fires the before callback', ->
      expect(beforeHit).toBeTruthy()

    it 'fires the after callback', ->
      expect(afterHit).toBeTruthy()

  describe 'when no more link on initialize', ->
    beforeEach ->
      $more.remove()
      $container.waypoint 'infinite'

    it 'does not create the waypoint', ->
      expect($.waypoints().vertical.length).toEqual 0

  afterEach ->
    $.waypoints 'destroy'
    $win.scrollTop 0

