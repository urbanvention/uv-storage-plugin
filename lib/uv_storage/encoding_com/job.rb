module Uv
  module Storage
    module EncodingCom
      
      class InvalidOutputFormat < StandardError; end;
      class MissingOutputFormat < StandardError; end;
      
      class Job
        
        # Queue of different encoding output formats for this job
        attr_reader :output_formats
        
        attr_accessor :source_url
        attr_accessor :callback_url
        attr_accessor :connection
        attr_accessor :logger
        
        ##
        # Create a new job instance for processing in the encoding.com queue. Make sure that your encoding.com
        # credentials are registered with your access_key (Application). 
        #
        # @see Base#register
        # @see Job#add_output_format
        # 
        # @example How to create a new job and send it
        #   @job = Uv::Storage::EncodingCom::Job.new('http://domain.com/url/to/source/file', 'http://domain.com/url/to/callback')
        #   @job.add_output_format(
        #     'iphone',                   # this is a identifier for this format, and will be used when sending 
        #                                 # the paths back to your callback
        #     {                           # your actual encoding instructions, see Job#add_output_format for available options
        #       'output' => 'flv',
        #       'size' => '608x0',
        #       'add_meta' => 'yes',
        #       'bitrate' => '1024k',
        #       'framerate' => '25',
        #       'video_codec' => 'libx264',
        #       'audio_bitrate' => '128k',
        #       'profile' => 'baseline',
        #       'two_pass' => 'yes'
        #     }
        #   )
        #   @job.process!                 # send the job
        # 
        # @param source_url   A url to a file stored in the Uv::Storage cloud. This can be either a protected or a public
        #                     file url
        # @param callback_url The url to call after the processing is finished. This will receive a job_id, status and the
        #                     path(s) to the encoding files. You can use +Uv::Storage::EncodingCom::Result to process
        #                     the result
        # 
        def initialize(source_url, callback_url)
          self.source_url     = source_url
          self.callback_url   = callback_url
          self.connection     = Uv::Storage::Connection.new
          self.logger         = Uv::Storage.logger
          @output_formats     = {}
        end
        
        ## 
        # Add a new encoding job to the queue
        # 
        # @see Job#initialize An example on how to use this
        # @see http://www.encoding.com/wdocs/ApiDoc#MainFields Encoding.com Documentation
        #
        # == Output formats
        # 
        # * flv 
        # * fl9
        # * wmv
        # * 3gp
        # * mp4
        # * m4v
        # * ipod
        # * iphone
        # * ipad
        # * android
        # * ogg
        # * webm
        # * appletv
        # * psp 
        # * zune
        # * mp3
        # * wma
        # * m4a
        # * thumbnail
        # * image
        # * mpeg2
        # * iphone_stream
        # * ipad_stream
        #  
        # == Video codecs
        # 
        # * <b>flv:</b> flv, libx264, vp6 **
        # * <b>fl9:</b> libx264
        # * <b>wmv, zune:</b> wmv2, msmpeg4
        # * <b>3gp, android:</b> h263, mpeg4, libx264
        # * <b>m4v:</b> mpeg4
        # * <b>mp4, ipod, iphone, ipad, appletv, psp:</b> mpeg4, libx264
        # * <b>ogg:</b> libtheora
        # * <b>webm:</b> libvpx
        # * <b>mp3, wma:</b> none
        # * <b>mpeg2:</b> mpeg2video
        #
        # == Audio bitrates
        # 
        # * <b>3gp:</b> 4.75k, 5.15k, 5.9k, 6.7k, 7.4k, 7.95k, 10.2k, 12.2k
        # * <b>flv, wmv, mp3, wma, zune:</b> 32k, 40k, 48k, 56k, 64k, 80k, 96k, 112k, 128k, 144k, 160k, 192k, 224k, 256k, 320k
        # * <b>ogg, webm:</b> 45k,64k, 80k, 96k, 112k, 128k, 160k, 192k, 224k, 256k, 320k, 500k
        # 
        # == Audio sample rates
        # 
        # * <b>3gp:</b> 8000
        # * <b>flv, mp3:</b> 11025, 22050, 44100
        # * <b>ogg, webm:</b> 16000, 32000, 44100, 22050, 11025, 192000
        # * <b>wmv, wma, zune:</b> 11025, 22050, 32000, 44100, 48000
        # * <b>mpeg2:</b> 44100, 48000
        # 
        # == Audio codecs
        # 
        # * <b>mp3:</b> libmp3lame
        # * <b>m4a:</b> libfaac
        # * <b>flv:</b> libmp3lame, libfaac
        # * <b>fl9, mp4, m4v, ipod, iphone, ipad, appletv, psp:</b> libfaac
        # * <b>wmv, wma, zune:</b> wmav2, libmp3lame
        # * <b>ogg, webm:</b> libvorbis
        # * <b>3gp:</b> libamr_nb
        # * <b>android:</b> libamr_nb, libfaac
        # * <b>mpeg2:</b> pcm_s16be, pcm_s16le
        #
        # @raise [InvalidOutputFormat] Raised if the format of your definition file is invalid, or required keys are 
        #                              missing
        # @param  [Hash] job_hash A hash with settings for the encoding job format
        # @param  [String] identifier Name for the encoding format, for later recognition of the path
        # 
        # @option job_hash [String]   :output required, Output format of this encoding. See above for allowed valyes
        # @option job_hash [String]   :size Size in pixels (WidthxHeight), if you set one of the values to 0 (e.g. 608x0) the video
        #                                   will be resized proportionally.
        # @option job_hash [Integer]  :bitrate Bitrate in kilobytes e.g. 1024k
        # @option job_hash [Integer]  :framerate Frames per second for the encdoded video e.g. 30
        # @option job_hash [String]   :video_codec The allowed values depend on the output format. See the above
        # @option job_hash [Integer]  :audio_bitrate Audio bitrate for the encoded media, see above.
        # @option job_hash [Integer]  :audio_sample_rate Audio sample rate for the encoded media, see above.
        # @option job_hash [Integer]  :audio_channels_number (2) Number of audio channels
        # @option job_hash [Integer]  :audio_volume (100) In percent
        # @option job_hash [String]   :two_pass (no) Wether to use two-pass or one-pass encoding. yes or no as string
        # @option job_hash [String]   :cbr (no) Whether to use CBR (Constant bitrate). yes or no as string
        # @option job_hash [String]   :acbr (no) Whether to use CBR (Constant bitrate) for audio. yes or no as string
        # @option job_hash [Integer]  :maxrate Maximum output bitrate for video encoding
        # @option job_hash [Integer]  :minrate Minimum output bitrate for video encoding
        # @option job_hash [Integer]  :bufsize Rate control buffer size
        # @option job_hash [Integer]  :keyframe (300) Keyframe period, in frames
        # @option job_hash [Integer]  :start (0) Start encoding from (in sec)
        # @option job_hash [Integer]  :duration End encoding after (in sec)
        # @option job_hash [Integer]  :rc_init_occupancy initial rate control buffer occupancy (bits).
        # @option job_hash [String]   :deinterlacing (no) Wether to use deinterlacing or not. Yes or no as string
        # @option job_hash [Integer]  :crop_top (0) How much to crop (in pixels)
        # @option job_hash [Integer]  :crop_left (0) How much to crop (in pixels)
        # @option job_hash [Integer]  :crop_right (0) How much to crop (in pixels)
        # @option job_hash [Integer]  :crop_bottom (0) How much to crop (in pixels)
        # @option job_hash [String]   :keep_aspect_ratio (yes) Yes or no as a string
        # @option job_hash [String]   :add_meta (no) Yes or no as a string, only for flv.
        # @option job_hash [String]   :hint MP4 only. Whether to add RTP data (for streaming servers).
        # @option job_hash [String]   :rotate (def) Video files only. 
        #                             * def - don't change anything. Video will be rotated according to 'Rotation' 
        #                               meta data parameter, if it exists
        #                             * 0 - don't rotate and ignore 'Rotation' meta data parameter 
        #                             * 90 - rotate by 90 degree CW and ignore 'Rotation' meta data parameter 
        #                             * 180 - rotate by 180 degree and ignore 'Rotation' meta data parameter 
        #                             * 270 - rotate by 270 degree CW and ignore 'Rotation' meta data parameter
        # @option job_hash [String]   :preset (6) webm format only. Specify format preset.
        #                             * 1 - 2-Pass Best Quality VBR Encoding
        #                             * 2 - 2-Pass Faster VBR Encoding
        #                             * 3 - 2-Pass VBR Encoding for Smooth Playback on Low-end Hardware
        #                             * 4 - 2-Pass CBR Encoding for Limited-bandwidth Streaming
        #                             * 5 - 2-Pass VBR Encoding for Noisy / Low-quality Input Source
        #                             * 6 - 1-Pass Good Quality VBR Encoding
        # @return [Boolean] true on success, false on failure
        #
        def add_output_format(identifier, job_hash)
          job_hash.stringify_keys!
          
          raise InvalidOutputFormat.new('output is missing') unless job_hash.has_key?('output')
          
          @output_formats[identifier.to_s] = job_hash
          
          return true
        end
        
        ##
        # Send of the job to the Uv::Storage master
        # 
        # @raise [MasterConnectionFailed] if the connection to the master fails
        # @raise [MissingOutputFormat] if no output formats are present
        # @see Job#add_output_format
        #
        def process!
          raise MissingOutputFormat.new if @output_formats.blank?
          
          @query = self.to_create_query
          
          begin
            @result = self.connection.request('/apis/encoding-com/jobs/create', 'post', @query)
          rescue => e
            logger.fatal 'An error occured in sending your encoding request'
            logger.fatal e
            raise e
          end
          
          return @result['job_id']
        end
        
        protected
        
          def to_create_query
            {
              'callback' => self.callback_url,
              'url' => self.source_url,
              'encoding_jobs' => JSON.generate(@output_formats)
            }
          end
        
      end
      
    end
  end
end