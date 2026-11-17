# The task does not require sending real emails, so in development emails are
# "delivered" by writing their full payload to the Rails log (visible in
# `docker compose logs web`). Use mailer previews at /rails/mailers to see
# rendered templates.
class LogDelivery
  def initialize(settings = {})
    @logger = settings[:logger] || Rails.logger
  end

  def deliver!(mail)
    @logger.info(<<~LOG)
      [EMAIL] ---------------------------------------------
      From:    #{Array(mail.from).join(', ')}
      To:      #{Array(mail.to).join(', ')}
      Subject: #{mail.subject}

      #{mail.body.decoded.strip}
      -----------------------------------------------------
    LOG
  end
end

ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :log, LogDelivery
end
