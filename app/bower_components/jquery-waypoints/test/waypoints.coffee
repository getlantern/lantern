$.waypoints.settings.scrollThrottle = 10
$.waypoints.settings.resizeThrottle = 20
standardWait = 50

# Go tests, go

describe 'jQuery Waypoints', ->
  hit = $se = $e = null

  beforeEach ->
    loadFixtures 'standard.html'
    $se = $ window
    hit = false

  describe '#waypoint()', ->
    it 'errors out', ->
      fn = -> $('#same1').waypoint()
      expect(fn).toThrow $.Error

  describe '#waypoint(callback)', ->
    currentDirection = null

    beforeEach ->
      currentDirection = null
      $e = $('#same1').waypoint (direction) ->
        currentDirection = direction
        hit = true

    it 'creates a waypoint', ->
      expect($.waypoints().vertical.length).toEqual 1
    
    it 'triggers the callback', ->
      runs ->
        $se.scrollTop $e.offset().top
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()

    it 'uses the default offset', ->
      runs ->
        $se.scrollTop($e.offset().top - 1)
      waits standardWait

      runs ->
        expect(hit).toBeFalsy()
        $se.scrollTop $e.offset().top
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()

    it 'passes correct directions', ->
      runs ->
        $se.scrollTop $e.offset().top
      waits standardWait

      runs ->
        expect(currentDirection).toEqual 'down'
        $se.scrollTop($e.offset().top - 1)
      waits standardWait

      runs ->
        expect(currentDirection).toEqual 'up'

  
  
  describe '#waypoint(options)', ->
    beforeEach ->
      $e = $ '#same1'
    
    it 'creates a waypoint', ->
      $e.waypoint
        offset: 1
        triggerOnce: true
      expect($.waypoints().vertical.length).toEqual 1
    
    it 'respects a px offset', ->
      runs ->
        $e.waypoint
          offset: 50
          handler: -> hit = true
        $se.scrollTop($e.offset().top - 51)
      waits standardWait

      runs ->
        expect(hit).toBeFalsy()
        $se.scrollTop($e.offset().top - 50)
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()
    
    it 'respects a % offset', ->
      pos = null

      runs ->
        $e.waypoint
          offset: '37%'
          handler: -> hit = true
        pos = $e.offset().top - $.waypoints('viewportHeight') * .37 - 1
        $se.scrollTop pos
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
        $se.scrollTop pos + 1
      waits standardWait
      
      runs ->
        expect(hit).toBeTruthy()
    
    it 'respects a function offset', ->
      runs ->
        $e.waypoint
          offset: ->
            $(this).height() * -1
          handler: -> hit = true
        $se.scrollTop($e.offset().top + $e.height() - 1)
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
        $se.scrollTop($e.offset().top + $e.height())
      waits standardWait
      
      runs ->
        expect(hit).toBeTruthy()
    
    it 'respects the bottom-in-view function alias', ->
      inview = $e.offset().top \
             - $.waypoints('viewportHeight') \
             + $e.outerHeight()
      
      runs ->
        $e.waypoint
          offset: 'bottom-in-view'
          handler: -> hit = true
        $se.scrollTop(inview - 1)      
      waits standardWait

      runs ->
        expect(hit).toBeFalsy()
        $se.scrollTop inview
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()
    
    it 'destroys the waypoint if triggerOnce is true', ->
      runs ->
        $e.waypoint
          triggerOnce: true
        $se.scrollTop $e.offset().top
      waits standardWait
      
      runs ->
        expect($.waypoints().length).toBeFalsy()
    
    it 'triggers if continuous is true and waypoint is not last', ->
      $f = $ '#near1'
      $g = $ '#near2'
      hitcount = 0
      
      runs ->
        $e.add($f).add($g).waypoint ->
          hitcount++
        $se.scrollTop $g.offset().top
      waits standardWait
      
      runs ->
        expect(hitcount).toEqual 3
    
    it 'does not trigger if continuous false, waypoint not last', ->
      $f = $ '#near1'
      $g = $ '#near2'
      hitcount = 0
      
      runs ->
        callback = ->
          hitcount++
        options =
          continuous: false
        $e.add($g).waypoint callback
        $f.waypoint callback, options
        $se.scrollTop $g.offset().top
      waits standardWait
      
      runs ->
        expect(hitcount).toEqual 2
    
    it 'triggers if continuous is false, waypoint is last', ->
      $f = $ '#near1'
      $g = $ '#near2'
      hitcount = 0
      
      runs ->
        callback = ->
          hitcount++
        options =
          continuous: false
        $e.add($f).waypoint callback
        $g.waypoint callback, options
        $se.scrollTop $g.offset().top
      waits standardWait
      
      runs ->
        expect(hitcount).toEqual 3
    
    it 'uses the handler option if provided', ->
      hitcount = 0
      
      runs ->
        $e.waypoint
          handler: (dir) ->
            hitcount++
        $se.scrollTop $e.offset().top
      waits standardWait
      
      runs ->
        expect(hitcount).toEqual 1
  
  describe '#waypoint(callback, options)', ->
    beforeEach ->
      callback = ->
        hit = true
      options =
        offset: -1
      $e = $('#same1').waypoint callback, options
    
    it 'creates a waypoint', ->
      expect($.waypoints().vertical.length).toEqual 1
    
    it 'respects options', ->
      runs ->
        $se.scrollTop $e.offset().top
      waits standardWait

      runs ->
        expect(hit).toBeFalsy()
        $se.scrollTop($e.offset().top + 1)
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()
    
    it 'fires the callback', ->
      runs ->
        $se.scrollTop($e.offset().top + 1)
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()

  describe '#waypoint("disable")', ->
    beforeEach ->
      $e = $('#same1').waypoint ->
        hit = true
      $e.waypoint 'disable'

    it 'disables callback triggers', ->
      runs ->
        $se.scrollTop $e.offset().top
      waits standardWait

      runs ->
        expect(hit).toBeFalsy()

  describe '.waypoint("enable")', ->
    beforeEach ->
      $e = $('#same1').waypoint ->
        hit = true
      $e.waypoint 'disable'
      $e.waypoint 'enable'

    it 'enables callback triggers', ->
      runs ->
        $se.scrollTop $e.offset().top
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()
  
  describe '#waypoint("destroy")', ->
    beforeEach ->
      $e = $('#same1').waypoint ->
        hit = true
      $e.waypoint 'destroy'
    
    it 'removes waypoint from list of waypoints', ->
      expect($.waypoints().length).toBeFalsy()
    
    it 'no longer triggers callback', ->
      runs ->
        $se.scrollTop $e.offset().top
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
    
    it 'does not preserve callbacks if .waypoint recalled', ->
      runs ->
        $e.waypoint({})
        $se.scrollTop $e.offset().top
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()

  describe '#waypoint("prev")', ->
    it 'returns jQuery object containing previous waypoint', ->
      $e = $ '#same1'
      $f = $ '#near1'
      $e.add($f).waypoint({})
      expect($f.waypoint('prev')[0]).toEqual $e[0]

    it 'can be used in a non-window context', ->
      $e = $ '#inner1'
      $f = $ '#inner2'
      $e.add($f).waypoint
        context: '#bottom'
      expect($f.waypoint('prev', 'vertical', '#bottom')[0]).toEqual $e[0]

  describe '#waypoint("next")', ->
    it 'returns jQuery object containing next waypoint', ->
      $e = $ '#same1'
      $f = $ '#near1'
      $e.add($f).waypoint({})
      expect($e.waypoint('next')[0]).toEqual $f[0]
  
  describe 'jQuery#waypoints()', ->
    it 'starts as an empty array for each axis', ->
      expect($.waypoints().vertical.length).toBeFalsy()
      expect($.waypoints().horizontal.length).toBeFalsy()
      expect($.isPlainObject $.waypoints()).toBeTruthy()
      expect($.isArray $.waypoints().horizontal).toBeTruthy()
      expect($.isArray $.waypoints().vertical).toBeTruthy()
    
    it 'returns waypoint elements', ->
      $e = $('#same1').waypoint({})
      expect($.waypoints().vertical[0]).toEqual $e[0]
    
    it 'does not blow up with multiple waypoint', ->
      $e = $('.sameposition, #top').waypoint({})
      $e = $e.add $('#near1').waypoint({})
      expect($.waypoints().vertical.length).toEqual 4
      expect($.waypoints().vertical[0]).toEqual $('#top')[0]

    it 'returns horizontal elements', ->
      $e = $('#same1').waypoint
        horizontal: true
      expect($.waypoints().horizontal[0]).toEqual $e[0]

    describe 'Directional filters', ->
      $f = null

      beforeEach ->
        $e = $ '#same1'
        $f = $ '#near1'

      describe 'above', ->
        it 'returns waypoints only above the current scroll position', ->
          runs ->
            $e.add($f).waypoint({})
            $se.scrollTop 1500
          waits standardWait

          runs ->
            expect($.waypoints('above')).toEqual [$e[0]]

      describe 'below', ->
        it 'returns waypoints only below the current scroll position', ->
          runs ->
            $e.add($f).waypoint({})
            $se.scrollTop 1500
          waits standardWait

          runs ->
            expect($.waypoints('below')).toEqual [$f[0]]

      describe 'left', ->
        it 'returns waypoints only left of the current scroll position', ->
          runs ->
            $e.add($f).waypoint
              horizontal: true
            $se.scrollLeft 1500
          waits standardWait

          runs ->
            expect($.waypoints('left')).toEqual [$e[0]]

      describe 'right', ->
        it 'returns waypoints only right of the current scroll position', ->
          runs ->
            $e.add($f).waypoint
              horizontal: true
            $se.scrollLeft 1500
          waits standardWait

          runs ->
            expect($.waypoints('right')).toEqual [$f[0]]

  
  describe 'jQuery#waypoints("refresh")', ->
    currentDirection = null
    
    beforeEach ->
      currentDirection = null
      $e = $('#same1').waypoint (direction) ->
        currentDirection = direction
    
    it 'triggers callback if refresh crosses scroll', ->
      runs ->
        $se.scrollTop($e.offset().top - 1)
      waits standardWait
      
      runs ->
        $e.css('top', ($e.offset().top - 50) + 'px')
        $.waypoints 'refresh'
        expect(currentDirection).toEqual 'down'
        expect(currentDirection).not.toEqual 'up'
        $e.css('top', $e.offset().top + 50 + 'px')
        $.waypoints 'refresh'
        expect(currentDirection).not.toEqual 'down'
        expect(currentDirection).toEqual 'up'

    
    it 'does not trigger callback if onlyOnScroll true', ->
      $f = null
    
      runs ->
        $f = $('#same2').waypoint
          onlyOnScroll: true
          handler: -> hit = true
        $se.scrollTop($f.offset().top - 1)
      waits standardWait
      
      runs ->
        $f.css('top', ($f.offset().top - 50) + 'px')
        $.waypoints 'refresh'
        expect(hit).toBeFalsy()
        $f.css('top', $f.offset().top + 50 + 'px')
        $.waypoints 'refresh'
        expect(hit).toBeFalsy()
    
    it 'updates the offset', ->
      runs ->
        $se.scrollTop($e.offset().top - 51)
        $e.css('top', ($e.offset().top - 50) + 'px')
        $.waypoints 'refresh'
      waits standardWait
      
      runs ->
        expect(currentDirection).toBeFalsy()
        $se.scrollTop $e.offset().top
      waits standardWait
      
      runs ->
        expect(currentDirection).toBeTruthy()
  
  describe 'jQuery#waypoints("viewportHeight")', ->
    it 'returns window innerheight if it exists', ->
      if window.innerHeight
        expect($.waypoints 'viewportHeight').toEqual window.innerHeight
      else
        expect($.waypoints 'viewportHeight').toEqual $(window).height()

  describe 'jQuery#waypoints("disable")', ->
    it 'disables all waypoints', ->
      count = 0

      runs ->
        $e = $('.sameposition').waypoint -> count++
        $.waypoints 'disable'
        $se.scrollTop($e.offset().top + 50)
      waits standardWait

      runs ->
        expect(count).toEqual 0

  describe 'jQuery#waypoints("enable")', ->
    it 'enables all waypoints', ->
      count = 0

      runs ->
        $e = $('.sameposition').waypoint -> count++
        $.waypoints 'disable'
        $.waypoints 'enable'
        $se.scrollTop($e.offset().top + 50)
      waits standardWait

      runs ->
        expect(count).toEqual 2

  describe 'jQuery#waypoints("destroy")', ->
    it 'destroys all waypoints', ->
      $e = $('.sameposition').waypoint({})
      $.waypoints 'destroy'
      expect($.waypoints().vertical.length).toEqual 0

  describe 'jQuery#waypoints("extendFn", methodName, function)', ->
    it 'adds method to the waypoint namespace', ->
      currentArg = null
      $.waypoints 'extendFn', 'myMethod', (arg) ->
        currentArg = arg
      $('#same1').waypoint 'myMethod', 'test'
      expect(currentArg).toEqual 'test'
  
  describe 'jQuery#waypoints.settings', ->
    count = curID = null
    
    beforeEach ->
      count = 0
      $('.sameposition, #near1, #near2').waypoint ->
        count++
        curID = $(this).attr 'id'
    
    it 'throttles the scroll check', ->
      runs ->
        $se.scrollTop $('#same1').offset().top
        expect(count).toEqual 0
      waits standardWait
      
      runs ->
        expect(count).toEqual 2
    
    it 'throttles the resize event and calls refresh', ->
      runs ->
        $('#same1').css 'top', "-1000px"
        $(window).resize()
        expect(count).toEqual 0
      waits standardWait
      
      runs ->
        expect(count).toEqual 1
  
  describe 'non-window scroll context', ->
    $inner = null
    
    beforeEach ->
      $inner = $ '#bottom'
    
    it 'triggers the waypoint within its context', ->
      $e = $('#inner3').waypoint
        context: '#bottom'
        handler: -> hit = true
      
      runs ->
        $inner.scrollTop 199
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
        $inner.scrollTop 200
      waits standardWait
      
      runs ->
        expect(hit).toBeTruthy()
    
    it 'respects % offsets within contexts', ->
      $e = $('#inner3').waypoint
        context: '#bottom'
        offset: '100%'
        handler: -> hit = true
      
      runs ->
        $inner.scrollTop 149
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
        $inner.scrollTop 150
      waits standardWait
      
      runs ->
        expect(hit).toBeTruthy()
    
    it 'respects function offsets within context', ->
      $e = $('#inner3').waypoint
        context: '#bottom'
        offset: ->
          $(this).height() / 2
        handler: -> hit = true
      
      runs ->
        $inner.scrollTop 149
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
        $inner.scrollTop 150
      waits standardWait
      
      runs ->
        expect(hit).toBeTruthy()
    
    it 'respects bottom-in-view alias', ->
      $e = $('#inner3').waypoint
        context: '#bottom'
        offset: 'bottom-in-view'
        handler: -> hit = true
      
      runs ->
        $inner.scrollTop 249
      waits standardWait
      
      runs ->
        expect(hit).toBeFalsy()
        $inner.scrollTop 250
      waits standardWait
      
      runs ->
        expect(hit).toBeTruthy()
    
    afterEach ->
      $inner.scrollTop 0
  
  describe 'Waypoints added after load, Issue #28, 62, 63', ->
    it 'triggers down on new but already reached waypoints', ->
      runs ->
        $e = $ '#same2'
        $se.scrollTop($e.offset().top + 1)
      waits standardWait
      
      runs ->
        $e.waypoint (direction) ->
          hit = direction is 'down'

      waitsFor (-> hit), '#same2 to trigger', 1000

  describe 'Multiple waypoints on the same element', ->
    hit2 = false

    beforeEach ->
      hit2 = false
      $e = $('#same1').waypoint
        handler: ->
          hit = true
      $e.waypoint
        handler: ->
          hit2 = true
        offset: -50

    it 'triggers all handlers', ->
      runs ->
        $se.scrollTop($e.offset().top + 50)
      waits standardWait

      runs ->
        expect(hit and hit2).toBeTruthy()

    it 'uses only one element in $.waypoints() array', ->
      expect($.waypoints().vertical.length).toEqual 1

    it 'disables all waypoints on the element when #disabled called', ->
      runs ->
        $e.waypoint 'disable'
        $se.scrollTop($e.offset().top + 50)
      waits standardWait

      runs ->
        expect(hit or hit2).toBeFalsy()

  describe 'Horizontal waypoints', ->
    currentDirection = null

    beforeEach ->
      currentDirection = null
      $e = $('#same1').waypoint
        horizontal: true
        handler: (direction) ->
          currentDirection = direction

    it 'triggers right/left direction', ->
      runs ->
        $se.scrollLeft $e.offset().left
      waits standardWait

      runs ->
        expect(currentDirection).toEqual 'right'
        $se.scrollLeft($e.offset().left - 1)
      waits standardWait

      runs ->
        expect(currentDirection).toEqual 'left'

  describe 'Waypoints attached to window object, pull request 86', ->
    $win = $ window;

    beforeEach ->
      $e = $win.waypoint
        offset: 
          -$win.height()
        handler: -> hit = true

    it 'triggers waypoint reached', ->
      runs ->
        $win.scrollTop($win.height() + 1)
      waits standardWait

      runs ->
        expect(hit).toBeTruthy()

  afterEach ->
    $.waypoints 'destroy'
    $se.scrollTop(0).scrollLeft 0
    hit = false
    waits standardWait
