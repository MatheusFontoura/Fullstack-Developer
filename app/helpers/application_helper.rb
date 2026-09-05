module ApplicationHelper
  def field_error(model, attribute)
    messages = model.errors[attribute]
    return if messages.empty?

    tag.p messages.to_sentence, class: "field-error", id: "#{attribute}_error"
  end

  def field_error_attributes(model, attribute)
    return {} if model.errors[attribute].empty?

    { aria: { invalid: true, describedby: "#{attribute}_error" } }
  end
end
