###
Infinite Scroll Shortcut for jQuery Waypoints - v2.0.3
Copyright (c) 2011-2013 Caleb Troughton
Dual licensed under the MIT license and GPL license.
https://github.com/imakewebthings/jquery-waypoints/blob/master/licenses.txt
###
((root, factory) ->
  if typeof define is 'function' and define.amd
    define ['jquery', 'waypoints'], factory
  else
    factory root.jQuery
) this, ($) ->

  # An extension of the waypoint defaults when calling the "infinite" method.

  # - container: Selector that matches a container around the items that are
  #   infinitely loaded. Newly loaded items will be appended to this container.
  #   If this value is set to 'auto' as it is by default, the container will be
  #   the element .waypoint is called on.

  # - items: Selector that matches the items to pull from each AJAX loaded
  #   page and append to the "container".

  # - more: Selector that matches the next-page link. The href attribute of
  #   this anchor is AJAX loaded and harvested for new items and a new "more"
  #   link during each waypoint trigger.

  # - offset: The same as the base waypoint offset. But in this case, we use
  #   bottom-in-view as the default instead of 0.

  # - loadingClass: This class is added to the container while new items are
  #   being loaded, and removed once they are loaded and appended.

  # - onBeforePageLoad: A callback function that is executed at the beginning
  #   of a page load trigger, before the AJAX request is sent.

  # - onAfterPageLoad: A callback function that is executed at the end of a new
  #   page load, after new items have been appended.
  defaults =
    container: 'auto'
    items: '.infinite-item'
    more: '.infinite-more-link'
    offset: 'bottom-in-view'
    loadingClass: 'infinite-loading'
    onBeforePageLoad: $.noop
    onAfterPageLoad: $.noop

  # .waypoint('infinite', [object])

  # The infinite method is a shortcut method for a common UI pattern, infinite
  # scrolling. This turns a traditional More/Next-Page style pagination into
  # an infinite scrolling page. The recommended usage is to call this method
  # on the container holding the items to be loaded. Ex:

  # $('.infinite-container').waypoint('infinite');

  # Using all of the default options, when the bottom of the infinite container
  # comes into view, a new page of items will be loaded. The script will look
  # for a link with the class of "infinite-more-link", grab its href attribute,
  # and load that page with AJAX. It will then search for all items in this new
  # page with a class of "infinite-item" and will append them to the
  # "infinite-container". The "infinite-more-link" item is also replaced with
  # the more link from the new page, allowing the next trigger to load the next
  # page. This continues until no new more link is detected in the loaded page.

  # An options object can optionally be passed in to override any of the
  # defaults specified above, as well as the baseline waypoint defaults.

  $.waypoints 'extendFn', 'infinite', (options) ->
    options = $.extend {}, $.fn.waypoint.defaults, defaults, options
    return @ if $(options.more).length is 0
    $container = if options.container is 'auto' then @ else $ options.container

    options.handler = (direction) ->
      if direction in ['down', 'right']
        $this = $ this
        options.onBeforePageLoad()

        # We disable the waypoint during item loading so that we can't trigger
        # it again and cause duplicate loads.
        $this.waypoint 'disable'

        # During loading a class is added to the container, should the user
        # wish to style it during this state.
        $container.addClass options.loadingClass

        # Load items from the next page.
        $.get $(options.more).attr('href'), (data) ->
          $data = $ $.parseHTML(data)
          $more = $ options.more
          $newMore = $data.find options.more
          $container.append $data.find options.items
          $container.removeClass options.loadingClass

          if $newMore.length
            $more.replaceWith $newMore
            $this.waypoint 'enable'
          else
            $this.waypoint 'destroy'
          options.onAfterPageLoad()

    # Initialize the waypoint with our built-up options. Returns the original
    # jQuery object per normal for chaining.
    @waypoint options
