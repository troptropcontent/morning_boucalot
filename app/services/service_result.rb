class ServiceResult
  attr_reader :data, :errors

  def self.success(data = nil) = new(success: true, data: data)
  def self.failure(errors) = new(success: false, errors: Array(errors))

  def initialize(success:, data: nil, errors: [])
    @success = success
    @data = data
    @errors = errors
  end

  def success? = @success
  def failure? = !@success
end
