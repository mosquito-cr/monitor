struct InteractiveLogStreamFormatter < Log::StaticFormatter
  def run
    severity
    string " "
    source
    string " "
    message
    string " "
    data
  end
end
