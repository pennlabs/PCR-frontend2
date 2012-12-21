###
  Logic for the auto-complete search-box, on the home-page and top-right of
  every page.  Uses the jQuery UI autocomplete plugin.
###


# Maximum number of items to show per type
MAX_ITEMS =
    Courses: 6
    Instructors: 3
    Departments: 3


endsWith = (str, suffix) ->
    str.indexOf suffix, str.length - suffix.length != -1

# Rules for prioritizing items
REGEXES_BY_PRIORITY =
  Courses: [
    ((search_term, course) ->
        RegExp("^#{search_term}", 'i').test(course.title)),
    ((search_term, course) ->
        RegExp("\\s#{search_term}", 'i').test(course.keywords)),
    ((search_term, course) ->
        RegExp(search_term, 'i').test(course.keywords))
  ],
  Instructors: [
    # if instructors = [Rebecca Stein, Steve Ballmer]
    # we want Stein to show up first when we type 'ste'
    # note, instructor.keywords is just the instruct name in lowercase

    # match last name
    ((search_term, instructor) ->
      # if it ends with a space, middle names will match the regex
      if endsWith search_term, " "
        false
      else
          RegExp("\\s#{search_term}[a-z]*$", 'i').test(instructor.keywords))

    # match first name
    ((search_term, instructor) ->
      RegExp("^#{search_term}", 'i').test(instructor.keywords))

    # match middle name
    ((search_term, instructor) ->
      RegExp("\\s#{search_term}", 'i').test(instructor.keywords))
  ],
  Departments: [
    ((search_term, department) ->
      RegExp("^#{search_term}", 'i').test(department.title))
    ((search_term, department) ->
      RegExp("^#{search_term}", 'i').test(department.keywords))
  ]


# Generate a list of interesting items to show for a given search term.
# @param user-entered search term
# @param type of items. Should be one of 'Courses', 'Instructors', or
#   'Departments'
# @param items to consider showing, in sorted order
# @param max number of items
# @return array of items to show
find_autocomplete_matches = (search_str, category, sorted_entries) ->
  # Regexes to match against, in order of interstingness
  results = []
  for match_test in REGEXES_BY_PRIORITY[category]
    for entry in sorted_entries
      # this regex matches this entry  and previous regex did not
      if match_test(search_str, entry) and entry not in results
        results.push(entry)
        if results.length is MAX_ITEMS[category]
          return results
  return results


# Get a list of interesting entries for a given search term
# @param user-entered search term
# @param list of all courses
# @param list of all instructors
# @param list of all departments
# @return list of interesting entries
get_entries = (term, courses, instructors, departments) ->
  find_autocomplete_matches(term, 'Courses', courses)
  .concat(find_autocomplete_matches(term, 'Instructors', instructors))
  .concat(find_autocomplete_matches(term, 'Departments', departments))


# Inject the category header (ex. instructor) before first result of each
# category
$.widget "custom.autocomplete", $.ui.autocomplete, _renderMenu: (ul, items) ->
  current_category = ""
  $.each items, (index, item) =>
    unless item.category == current_category
      li = "<li class='ui-autocomplete-category'><p>#{item.category}</p></li>"
      ul.append(li)
      current_category = item.category
    @_renderItem(ul, item)


# Initialize searchbox
# @param base directory
window.init_search_box = (dir="", callback=null, start) ->

  # put the data in the right order (cis 120 before cis 500)
  sort_by_title = (first, second) ->
    if first.title > second.title then 1 else -1
  $.getJSON dir+"autocomplete_data.json/"+start, (data) ->
    instructors = data.instructors.sort(sort_by_title)
    courses = data.courses.sort(sort_by_title)
    departments = data.departments.sort(sort_by_title)
    console.log "have data"

    $("#searchbox").autocomplete(
      delay: 0
      minLength: 2
      autoFocus: true
      source: (request, response) ->
        # update the entries to show
        response(get_entries(request.term, courses, instructors, departments))
      position:
        my: "left top"
        at: "left bottom"
        collision: "none"
        of: "#searchbar"
        offset: "0 -1"
      focus: (event, ui) ->
        false
      select: (event, ui) ->
        # On click, go to page
        window.location = dir+ui.item.url
        false
      open: (event, ui) ->
        $(".ui-autocomplete.ui-menu.ui-widget").width(
          $("#searchbar").width()
        )
    )
    .data("autocomplete")._renderItem = (ul, item) ->
      $("<li></li>")
      .data("item.autocomplete", item)
      .append("""<a>
                   <span class='ui-menu-item-title'>#{item.title}</span><br />
                   <span class='ui-menu-item-desc'>#{item.desc}</span>
                 </a>""")
      .appendTo(ul)
    # did the auto_complete.json have a callback? call it.
    callback() if callback?
