
import to_json from require "lapis.util"
date = require "date"

class EditStreak extends require "widgets.base"
  @include "widgets.form_helpers"

  js_init: =>
    opts = {}
    "new S.EditStreak(#{@widget_selector!}, #{to_json opts});"

  inner_content: =>
    if @streak
      h2 "Edit streak"
    else
      h2 "New streak"

    streak = @streak or {}

    form method: "post", class: "form", ->
      @csrf_input!
      @text_input_row {
        label: "Title"
        name: "streak[title]"
        value: streak.title
      }

      @text_input_row {
        label: "Short description"
        sub: "A single line describing the streak"
        name: "streak[short_description]"
        value: streak.short_description
      }

      @text_input_row {
        type: "textarea"
        label: "Description"
        name: "streak[description]"
        value: streak.description
      }

      div class: "input_row duration_row", ->
        div class: "label", ->
          text "Duration"
          span class: "sub", ->
            raw " &mdash; When does the streak start and stop"

        div ->
          label ->
            span class: "duration_label", "Start date:"
            input {
              type: "text"
              class: "date_picker start_date"
              name: "streak[start_date]"
              readonly: "readonly"
              value: @format_date_for_input streak.start_date
            }

          label ->
            span class: "duration_label", "End date:"
            input {
              type: "text"
              class: "date_picker end_date"
              name: "streak[end_date]"
              readonly: "readonly"
              value: @format_date_for_input streak.end_date
            }

          span class: "duration_summary"

      div class: "buttons", ->
        button class: "button", "Save"

  format_date_for_input: (timestamp) =>
    return unless timestamp
    date(timestamp)\fmt "%m/%d/%Y"
