db = require "lapis.db"
import Model, enum from require "lapis.db.model"

import safe_insert from require "helpers.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE notifications (
--   id integer NOT NULL,
--   user_id integer NOT NULL,
--   type integer DEFAULT 0 NOT NULL,
--   object_type integer DEFAULT 0 NOT NULL,
--   object_id integer DEFAULT 0 NOT NULL,
--   count integer DEFAULT 0 NOT NULL,
--   seen boolean DEFAULT false NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY notifications
--   ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);
-- CREATE INDEX notifications_user_id_seen_id_idx ON notifications USING btree (user_id, seen, id);
-- CREATE UNIQUE INDEX notifications_user_id_type_object_type_object_id_idx ON notifications USING btree (user_id, type, object_type, object_id) WHERE (NOT seen);
--
class Notifications extends Model
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
  }

  @types: enum {
    comment: 1
    mention: 2
    follow: 3
    like: 4
    join: 5
    approve_join: 6
  }

  @object_types: enum {
    submission: 1
    submission_comment: 2
    user: 3
    streak: 4
  }

  preloaders = {
    submission: {"Submissions"}
    submission_comment: {
      "SubmissionComments"
      (notes) ->
        import Submissions from require "models"
        Submissions\include_in [n.object for n in *notes], "submission_id"
    }
    user: {"Users"}
    streak: {"Streaks"}
  }

  @preload_objects: (notifications) =>
    models = require "models"

    for otype, {cls, post} in pairs preloaders
      filtered = [n for n in *notifications when n.object_type == @object_types[otype]]
      models[cls]\include_in filtered, "object_id", as: "object"
      post filtered if post

    import NotificationObjects from require "models"
    NotificationObjects\include_in notifications, "notification_id", flip: true, many: true

    notification_objects = {}
    for n in *notifications
      if objs = n.notification_objects
        for no in *objs
          table.insert notification_objects, no

    NotificationObjects\preload_objects notification_objects
    notifications

  @object_type_for_object: (object) =>
    switch object.__class.__name
      when "Submissions"
        @@object_types.submission
      when "SubmissionComments"
        @@object_types.submission_comment
      when "Users"
        @@object_types.user
      when "Streaks"
        @@object_types.streak
      else
        error "unknown object"

  @notify_for: (user, object, notify_type, target_object) =>
    return unless user
    import NotificationObjects from require "models"

    notify_type = @types\for_db notify_type
    object_type = @object_type_for_object object

    create_params = {
      user_id: user.id
      object_type: object_type
      object_id: object.id
      count: 1
      type: notify_type
    }

    ident_params = {
      user_id: user.id
      object_type: object_type
      object_id: object.id
      type: notify_type
      seen: false
    }

    res = safe_insert @, create_params, ident_params

    if (res.affected_rows or 0) > 0
      notification = unpack res
      if target_object
        NotificationObjects\create_for_object notification.id, target_object

      return "create", Notifications\load notification

    db.update @table_name!, {
      count: db.raw "count + 1"
      updated_at: db.format_date!
    }, ident_params

    if notification = target_object and @find(ident_params)
      NotificationObjects\create_for_object notification.id, target_object

    "update"

  -- TODO: make this decrement, then delete
  @undo_notify: (user, object, notify_type) =>
    return unless user

    import NotificationObjects from require "models"

    notify_type = @types\for_db notify_type
    object_type = @object_type_for_object object

    ident_params = {
      user_id: user.id
      object_type: object_type
      object_id: object.id
      type: notify_type
      seen: false
    }

    res = unpack db.query "
      delete from #{db.escape_identifier @table_name!}
      where #{db.encode_clause ident_params}
      returning id
    "

    if res
      db.query "
        delete from #{db.escape_identifier NotificationObjects\table_name!}
        where notification_id = ?
      ", res.id

    res

  prefix: =>
    switch @type
      when @@types.comment
        if @count == 1
          "You got a comment on"
        else
          "You got #{@count} comments on"
      when @@types.mention
        "You got mentioned in"
      when @@types.follow
        "You got followed by"
      when @@types.like
        if @count == 1
          "You got a like on"
        else
          "You got #{@count} likes on"
      when @@types.join
        if @count == 1
          "Somone joined "
        else
          "#{@count} people joined "
      when @@types.approve_join
        "You can now post in "
      else
        error "unknown notification type"

  object_title: =>
    switch @object_type
      when @@object_types.submission
        @object.title or "your submission"
      when @@object_types.submission_comment
        "a comment"
      when @@object_types.user
        @object\name_for_display!
      else
        @object.title

  mark_seen: =>
    @update seen: true

  show_join_usernames: =>
    return false unless @type == @@types.join
    return false unless @notification_objects
    return false unless next @notification_objects
    return false if #@notification_objects > 10
    true

