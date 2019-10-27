class TopicDueDate < DueDate
  belongs_to :topic, class_name: 'SignUpTopic', foreign_key: 'parent_id'
  belongs_to :deadline_type, class_name: 'DeadlineType', foreign_key: 'deadline_type_id'

  # adds a new deadline if not present,
  # updates the date if already present
  def self.modify_drop_deadline(topic, drop_topic_date)
    # can create constants for all deadline types and use those when required
    deadline_type_id = DeadlineType.find_by_name("drop_topic").id
    topic_due_date = TopicDueDate.where(parent_id: topic.id, deadline_type_id: deadline_type_id).first rescue nil
    if topic_due_date.nil?
      # save the newly entered date
      TopicDueDate.create(
        due_at: drop_topic_date,
        parent_id: topic.id,
        deadline_type_id: deadline_type_id,
        type: DeadlineHelper::TOPIC_DEADLINE_TYPE)
    else
      # update the existing date if different
      if topic_due_date.due_at != drop_topic_date
        topic_due_date.update_attributes(
          due_at: drop_topic_date
        )
      end
    end
  end
end
