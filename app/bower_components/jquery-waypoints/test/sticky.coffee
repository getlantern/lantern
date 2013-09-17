$.waypoints.settings.scrollThrottle = 10
$.waypoints.settings.resizeThrottle = 20
standardWait = 50

describe 'Waypoints Sticky Elements Shortcut', ->
  $sticky = $return = handlerSpy = null
  $win = $ window

  beforeEach ->
    loadFixtures 'sticky.html'
    $sticky = $ '.sticky'
    handlerSpy = jasmine.createSpy 'on handler'
    $return = $sticky.waypoint 'sticky',
      handler: handlerSpy

  it 'returns the same jQuery object for chaining', ->
    expect($return.get()).toEqual $sticky.get()

  it 'wraps the sticky element', ->
    expect($sticky.parent()).toHaveClass 'sticky-wrapper'

  it 'gives the wrapper the same height as the sticky element', ->
    expect($sticky.parent().height()).toEqual $sticky.outerHeight()

  it 'adds stuck class when you reach the element', ->
    runs ->
      $win.scrollTop $sticky.offset().top
    waits standardWait

    runs ->
      expect($sticky).toHaveClass 'stuck'
      $win.scrollTop $win.scrollTop()-1
    waits standardWait

    runs ->
      expect($sticky).not.toHaveClass 'stuck'

  it 'executes handler option after stuck class applied', ->
    runs ->
      $win.scrollTop $sticky.offset().top
    waits standardWait

    runs ->
      expect(handlerSpy).toHaveBeenCalled()

  describe '#waypoint("unsticky")', ->
    beforeEach ->
      $return = $sticky.waypoint 'unsticky'

    it 'returns the same jQuery object for chaining', ->
      expect($return.get()).toEqual $sticky.get()

    it 'unwraps the sticky element', ->
      expect($sticky.parent()).not.toHaveClass 'sticky-wrapper'

    it 'should not have stuck class', ->
      expect($sticky).not.toHaveClass 'stuck'

  afterEach ->
    $.waypoints 'destroy'
    $win.scrollTop 0

