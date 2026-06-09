class ApplicationService
  class ServiceError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = Array(errors)
      super(@errors.join(", "))
    end
  end

  def self.call(...)
    ServiceResult.success(new(...).call)
  rescue ServiceError => e
    ServiceResult.failure(e.errors)
  end

  private

  def fail!(errors)
    raise ServiceError.new(errors)
  end
end
