class Waitlist < ActiveRecord::Base
  def self.cancel_all_waitlists(team_id, assignment_id)
    waitlisted_topics = SignUpTopic.find_waitlisted_topics(assignment_id, team_id)
    unless waitlisted_topics.nil?
      for waitlisted_topic in waitlisted_topics
        entry = SignedUpTeam.find(waitlisted_topic.id)
        entry.destroy
        ExpertizaLogger.info LoggerMessage.new('Waitlist', '', "Waitlisted topic deleted with id: #{waitlisted_topic.id}")
      end
    end
  end

  # remove waitlisted teams for a particular topic
  def self.drop_teams_waitlisted_for_topic(topic_id)
    waitlisted_teams = SignedUpTeam.find_waitlisted_teams_for_topic(topic_id).destroy_all
  end
end
