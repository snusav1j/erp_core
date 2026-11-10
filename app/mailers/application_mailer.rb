class ApplicationMailer < ActionMailer::Base
  layout 'mailer'
  helper ApplicationHelper

  def document_template(to:, version:, data:, filename:, content_type:)
    @version = version

    attachments[filename] = {
      mime_type: content_type,
      content: data
    }

    mail(
      to: to,
      subject: 'ErpCore'
    )
  end
end