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
        due_at: drop_topic_deadline,
        parent_id: topic.id,
        deadline_type_id: deadline_type_id,
        type: DeadlineHelper::TOPIC_DEADLINE_TYPE)
      # Add a job to the queue for deletion of wait-listed teams after drop deadline passes
      # false attribute in the below call indicates absence of an old job
      delayed_job_id = modify_delayed_job(topic.id, drop_topic_date, nil, false)
    else
      # update the existing date if different
      if topic_due_date.due_at != drop_topic_deadline
        topic_due_date.update_attributes(
          due_at: drop_topic_deadline
        )
        # true attribute in the below call indicates presence of an old job
        delayed_job_id = modify_delayed_job(topic.id, drop_topic_date, topic_due_date.delayed_job_id, true)
      end
    end
    # set the delayed job id for the topic
    topic_due_date = TopicDueDate.where(parent_id: topic.id, deadline_type_id: deadline_type_id).first rescue nil
    topic_due_date.update_attributes(delayed_job_id: delayed_job_id)
  end

  # This method either adds a new job to the queue or deletes
  # an existing job and replaces it with a new one
  def self.modify_delayed_job(topic_id, drop_topic_date, delayed_job_id, job_present)
    mins_left = calculate_mins_left(drop_topic_date)
    if job_present == false
      delayed_job_id = add_job_to_queue(mins_left, topic_id, "drop_topic", drop_topic_date)
      delayed_job_id
    else
      remove_job_from_queue(delayed_job_id)
      delayed_job_id = add_job_to_queue(mins_left, topic_id, "drop_topic", drop_topic_date)
      delayed_job_id
    end
  end

  def self.calculate_mins_left(drop_topic_date)
    drop_topic_date = Time.parse(drop_topic_date)
    curr_time = DateTime.now.in_time_zone(zone = 'UTC').to_s(:db)
    curr_time = Time.parse(curr_time)
    time_in_min = ((drop_topic_date - curr_time).to_i / 60)
    time_in_min
  end

  def self.add_job_to_queue(min_left, topic_id, deadline_type, due_at)
    delayed_job_id = MailWorker.perform_in(min_left * 60, topic_id, deadline_type, due_at)
    return delayed_job_id
  end

  def self.remove_job_from_queue(job_id)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      current_job_id = job.args.first
      job.delete if job_id == current_job_id
    end
  end

end
