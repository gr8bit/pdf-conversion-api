# frozen_string_literal: true

require "sinatra/base"
require "open3"
require "time"
require "securerandom"
require "timeout"

class PdfConversionApi < Sinatra::Base
  VENDOR_DIR = File.expand_path("vendor", __dir__).freeze
  ICC_PROFILE = File.join(VENDOR_DIR, "sRGB.icc").freeze
  PDFA_DEF = File.join(VENDOR_DIR, "PDFA_def.ps").freeze
  ZUGFERD_PS = File.join(VENDOR_DIR, "zugferd.ps").freeze

  MAX_UPLOAD_BYTES = Integer(ENV.fetch("MAX_UPLOAD_MB", 50)) * 1024 * 1024
  GS_TIMEOUT = Integer(ENV.fetch("GS_TIMEOUT", 60))
  HEADER_LIMIT = 4096

  configure do
    set :show_exceptions, false
  end

  before do
    if request.post? && request.content_length.to_i > MAX_UPLOAD_BYTES
      halt 413, { "Content-Type" => "text/plain" }, "upload exceeds #{MAX_UPLOAD_BYTES / 1024 / 1024} MB limit"
    end
  end

  get "/health" do
    content_type :text
    "ok"
  end

  post "/to_pdfa3" do
    halt 400, { "Content-Type" => "text/plain" }, "missing 'file' parameter" unless params[:file]

    input_path = save_upload(params[:file])
    output_path = tmp_path("pdfa3")

    cmd = [
      "gs",
      "--permit-file-read=#{VENDOR_DIR}/",
      "-sDEVICE=pdfwrite",
      "-dPDFA=3",
      "-dPDFACompatibilityPolicy=2",
      "-sICCProfile=#{ICC_PROFILE}",
      "-sColorConversionStrategy=RGB",
      "-o", output_path,
      PDFA_DEF,
      input_path
    ]

    success, log = run_gs(cmd)

    unless success
      halt 500, { "Content-Type" => "text/plain" }, log
    end

    headers "X-Ghostscript-Log" => encode_header(log)
    content_type "application/pdf"
    attachment "pdfa3.pdf"
    File.binread(output_path)
  ensure
    File.delete(input_path) rescue nil if input_path
    File.delete(output_path) rescue nil if output_path
  end

  post "/to_zugferd" do
    halt 400, { "Content-Type" => "text/plain" }, "missing 'file' parameter" unless params[:file]
    halt 400, { "Content-Type" => "text/plain" }, "missing 'xml' parameter" unless params[:xml]
    halt 400, { "Content-Type" => "text/plain" }, "missing 'date' parameter" unless params[:date]

    input_path = save_upload(params[:file])
    xml_path = save_upload(params[:xml], suffix: ".xml")
    invoice_date = parse_date(params[:date])
    halt 400, { "Content-Type" => "text/plain" }, "invalid 'date' parameter, use ISO 8601" unless invoice_date

    pdf_date = format_pdf_date(invoice_date)
    output_path = tmp_path("zugferd")

    cmd = [
      "gs",
      "--permit-file-read=#{VENDOR_DIR}/",
      "--permit-file-read=#{xml_path}",
      "-sDEVICE=pdfwrite",
      "-dPDFA=3",
      "-dPDFACompatibilityPolicy=2",
      "-sColorConversionStrategy=RGB",
      "-sZUGFeRDXMLFile=#{xml_path}",
      "-sZUGFeRDDateTime=#{pdf_date}",
      "-sZUGFeRDProfile=#{ICC_PROFILE}",
      "-sZUGFeRDVersion=2p1",
      "-sZUGFeRDConformanceLevel=BASIC",
      "-o", output_path,
      ZUGFERD_PS,
      input_path
    ]

    success, log = run_gs(cmd)

    unless success
      halt 500, { "Content-Type" => "text/plain" }, log
    end

    headers "X-Ghostscript-Log" => encode_header(log)
    content_type "application/pdf"
    attachment "zugferd.pdf"
    File.binread(output_path)
  ensure
    File.delete(input_path) rescue nil if input_path
    File.delete(xml_path) rescue nil if xml_path
    File.delete(output_path) rescue nil if output_path
  end

  private

  def run_gs(cmd)
    log = nil
    Timeout.timeout(GS_TIMEOUT) do
      log, status = Open3.capture2e(*cmd, binmode: true)
      log = log.encode("UTF-8", invalid: :replace, undef: :replace)
      [status.exitstatus&.zero?, log]
    end
  rescue Timeout::Error
    [false, "ghostscript timed out after #{GS_TIMEOUT}s"]
  end

  def encode_header(log)
    result = +""
    remaining_chars = log.length
    log.each_char do |char|
      remaining_chars -= 1

      encoded = char.bytes.map { |b|
        b >= 0x20 && b <= 0x7E && b != 0x25 ? b.chr : "%%%02X" % b
      }.join
      total_size = result.bytesize + encoded.bytesize
      if total_size > HEADER_LIMIT || total_size == HEADER_LIMIT && remaining_chars > 0
        # will overflow, so truncate and add padding to reach the limit
        result << "~" * (HEADER_LIMIT - result.bytesize)
        break
      end
      result << encoded
    end

    result
  end

  def save_upload(upload, suffix: ".pdf")
    path = tmp_path("upload", suffix)
    File.open(path, "wb") do |f|
      if upload.is_a?(Hash)
        IO.copy_stream(upload[:tempfile], f)
      else
        f.write(upload)
      end
    end
    path
  end

  def tmp_path(prefix, suffix = ".pdf")
    File.join(Dir.tmpdir, "#{prefix}-#{SecureRandom.hex(8)}#{suffix}")
  end

  def parse_date(str)
    Time.iso8601(str)
  rescue ArgumentError
    nil
  end

  def format_pdf_date(time)
    offset = time.strftime("%z").sub(/([+-]\d{2})(\d{2})/, "\\1'\\2'")
    "D:#{time.strftime('%Y%m%d%H%M%S')}#{offset}"
  end
end
