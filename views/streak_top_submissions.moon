
StreakHeader = require "widgets.streak_header"
SubmissionList = require "widgets.submission_list"

class StreakTopSubmissions extends require "widgets.base"
  page_name: "top_submissions"
  base_widget: false

  inner_content:  =>
    widget StreakHeader page_name: @page_name

    div class: "responsive_column", ->
      @column_content!

  column_content: =>
    unless next @submissions
      p class: "empty_message", "No submissions"
      return

    if next @submissions
      widget SubmissionList


