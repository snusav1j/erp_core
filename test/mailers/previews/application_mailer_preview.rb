class ApplicationMailerPreview < ActionMailer::Preview
  def document_template_preview
    version = DocumentTemplateVersion.last
    record = version.document_template.sample_records.last

    exporter = DocumentTemplateExporter.new(
      version,
      version.document_template_structure,
      record
    )

    ApplicationMailer.document_template(
      to: 'test@example.com',
      version: version,
      data: exporter.render,
      filename: exporter.filename,
      content_type: exporter.content_type
    )
  end
end