class TopicDueDate < DueDate
  belongs_to :topic, class_name: 'SignUpTopic', foreign_key: 'parent_id'
  belongs_to :deadline_type, class_name: 'DeadlineType', foreign_key: 'deadline_type_id'

  # adds a new deadline if not present,
  # updates the date if already present
  def self.modify_drop_deadline(assignment_id, topic, drop_topic_deadline)
    if drop_topic_deadline.nil?
      drop_topic_date = DueDate.get_drop_topic_deadline(assignment_id, topic.id)
    else
      drop_topic_date = DateTime.parse(drop_topic_deadline).strftime("%Y-%m-%d %H:%M")
    end
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
      # Add a job to the queue for deletion of wait-listed teams after drop deadline passes
      # false attribute in the below call indicates absence of an old job
      delayed_job_id = DeadlineHelper.modify_delayed_job(topic, nil, false)
    else
      # update the existing date if different
      if topic_due_date.due_at != drop_topic_date
        topic_due_date.update_attributes(
          due_at: drop_topic_date
        )
      end
      # true attribute in the below call indicates presence of an old job
      delayed_job_id = DeadlineHelper.modify_delayed_job(topic, topic_due_date.delayed_job_id, true)
    end
    # set the delayed job id for the topic
    topic_due_date = TopicDueDate.where(parent_id: topic.id, deadline_type_id: deadline_type_id).first rescue nil
    topic_due_date.update_attributes(delayed_job_id: delayed_job_id)
  end
end
