

class Streaks extends require "widgets.base"
  inner_content: =>
    h2 "Streaks"
    div class: "streak_list", ->
      for streak in *@streaks
        div class: "streak_row", ->
          h3 ->
            a href: @url_for(streak), streak.title
            text " by "
            a href: @url_for(streak.user), streak.user\name_for_display!


          div "Submissions: #{streak.submissions_count}"
          h4 streak.short_description

          if streak\allowed_to_edit @current_user
            p ->
              a href: @url_for("edit_streak", id: streak.id), "Edit"

