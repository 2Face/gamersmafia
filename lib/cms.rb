prev_verbose = $VERBOSE
$VERBOSE = nil
begin
  class Tidybuf

    # Mimic TidyBuffer.
    #
    TidyBuffer = struct [
    "int* allocator",
    "byte* bp",
    "uint size",
    "uint allocated",
    "uint next"
    ]
  end
rescue
end
$VERBOSE = prev_verbose



require 'RMagick'
require 'net/http'
require 'open-uri'
require 'timeout'
require 'uri'

module Cms
  # Este módulo contiene toda la información de todos los tipos de contenidos
  # específicos
  # Atributos comunes a todas las clases de contenidos
  COMMON_CLASS_ATTRIBUTES = [
      :created_on,
      :updated_on,
      :user_id,
      :approved_by_user_id,
      :hits_registered,
      :hits_anonymous,
      :cache_rating,
      :cache_rated_times,
      :cache_weighted_rank,
      :cache_comments_count,
      :log,
      :state,
      :closed,
      :terms,
      :source,
  ]

  DRAFT = 0
  PENDING = 1
  PUBLISHED = 2
  DELETED = 3
  ONHOLD = 4 # estado especial para contenidos que temporalmente queremos q estén en el limbo, no públicos

  IMG_SIZE_GRID3 = '143x143'
  IMG_SIZE_GRID2 = '90x90'
  IMG_SIZE_GRIDB1 = '58x58'
  IMGWG6 = 308
  IMGWG5 = 253
  IMGWG4 = 198
  IMGWG3 = 143
  IMGWG2 = 88
  IMGWG1 = 33

  IMG_ARTICLE_THUMB = "#{IMGWG4}x54"

  IMAGE_FORMAT = /\.(jpg|gif|png|jpeg|bmp)$/i

  ROOT_TERMS_CONTENTS = %w(
      Bet
      Column
      Coverage
      Demo
      Event
      Interview
      News
      Poll
      RecruitmentAd
      Review
  )

  CATEGORIES_TERMS_CONTENTS = %w(
      Image
      Download
      Topic
      Tutorial
      Question
  )

  NO_MODERATION_NEEDED_CONTENTS = %w(
      Topic
      Blogentry
      Question
      RecruitmentAd
  )

  DONT_PARSE_IMAGES_OF_CONTENTS = %w(
      Blogentry
      RecruitmentAd
      Topic
  )

  AUTHOR_CAN_EDIT_CONTENTS = %w(
      Blogentry
      RecruitmentAd
  )

  CONTENTS_WITH_CATEGORIES = %w(
      Bet
      Column
      Coverage
      Demo
      Download
      Event
      Image
      Interview
      News
      Poll
      Question
      RecruitmentAd
      Review
      Topic
      Tutorial
  )

  BAZAR_DISTRICTS_VALID = %w(
      Bet
      Column
      Download
      Event
      Image
      Interview
      News
      Poll
      Question
      Review
      Topic
      Tutorial
  )

  BAZAR_DISTRICTS_REQUIRED = %w(
      News
      Poll
      Question
      Topic
  )

  CLANS_CONTENTS = %w(
      News
      Topic
      Download
      Image
      Event
      Poll
  )

  SAFE_PUBLICATION_THRESHOLDS = {
      'Bet' => 86400 * 7,
      'Column' => 86400 * 30,
      'Coverage' => 86400 * 14,
      'Demo' => 86400 * 14,
      'Download' => 86400 * 14,
      'Event' => 86400 * 14,
      'Image' => 86400 * 14,
      'Interview' => 86400 * 60,
      'News' => 86400 * 14,
      'Poll' => 86400 * 14,
      'Question' => 86400 * 14,
      'RecruitmentAd' => 86400 * 14,
      'Review' => 86400 * 30,
      'Tutorial' => 86400 * 30,
  }

  WYSIWYG_ATTRIBUTES = {
      'Bet' => ['description'],
      'Column' => ['description', 'main'],
      'Coverage' => ['description', 'main'],
      'Demo' => ['description'],
      'Download' => ['description'],
      'Event' => ['description'],
      'Funthing' => ['description'],
      'Image' => ['description'],
      'Interview' => ['description', 'main'],
      'News' => ['description', 'main'],
      'Poll' => [],
      'Question' => ['description'],
      'Review' => ['description', 'main'],
      'Tutorial' => ['description', 'main'],
  }

  CLASS_NAMES = {
      'Bet' => 'apuesta',
      'Blogentry' => 'entrada de blog',
      'Column' => 'columna',
      'Comments' => 'comentario',
      'Coverage' => 'coverage',
      'Demo' => 'demo',
      'Download' => 'descarga',
      'Event' => 'evento',
      'Funthing' => 'curiosidad',
      'Image' => 'imagen',
      'Interview' => 'entrevista',
      'News' => 'noticia',
      'Poll' => 'encuesta',
      'Question' => 'pregunta',
      'RecruitmentAd' => 'anuncio de reclutamiento',
      'Review' => 'review',
      'Topic' => 'tópic',
      'Tutorial' => 'tutorial',
  }

  def self.contents_classes
    [
     Bet,
     Column,
     Coverage,
     Demo,
     Download,
     Event,
     Funthing,
     Image,
     Interview,
     News,
     Poll,
     Question,
     RecruitmentAd,
     Review,
     Topic,
     Tutorial,
    ]
  end

  def self.contents_classes_symbols
    [
     :bet,
     :column,
     :coverage,
     :demo,
     :download,
     :event,
     :funthing,
     :image,
     :interview,
     :news,
     :poll,
     :question,
     :recruitment_ad,
     :review,
     :topic,
     :tutorial,
    ]
  end

  def self.contents_classes_publishable
    self.contents_classes - [Topic, Blogentry, Question, RecruitmentAd]
  end

  def self.uncompress_ckeditor_if_necessary
    if !File.exists?("#{Rails.root}/public/ckeditor")
      system("tar xfz \"#{Rails.root}/public/ckeditor_3.0.1.tar.gz\" -C public")
      system("cat \"#{Rails.root}/public/ckeditor/lang/es.js\" >> \"#{Rails.root}/public/ckeditor/ckeditor.js\"")
      system("cat \"#{Rails.root}/public/ckeditor_custom.js\" >> \"#{Rails.root}/public/ckeditor/ckeditor.js\"")
    end
  end

  # Returns the content name out of taxonomy name.
  # Args:
  # - taxonomy_name: eg. ImagesCategory
  #
  # Returns:
  # - "Image"
  def self.extract_content_name_from_taxonomy(taxonomy_name)
    ActiveSupport::Inflector::singularize(taxonomy_name.gsub('Category', ''))
  end


  def self.taxonomy_from_content_name(content_name)
    "#{ActiveSupport::Inflector::pluralize(content_name)}Categories"
  end

  CONTENTS_CONTROLLERS = {
    'News' => 'noticias',
    'Image' => 'imagenes',
    'Download' => 'descargas',
    'Demo' => 'demos',
    'Topic' => 'foros',
    'Blogentry' => 'entradas-de-blogs',
    'Poll' => 'encuestas',
    'Question' => 'respuestas',
    'Bet' => 'apuestas',
    'Event' => 'eventos',
    'Tutorial' => 'tutoriales',
    'Column' => 'columnas',
    'Interview' => 'entrevistas',
    'Review' => 'reviews',
    'Funthing' => 'curiosidades',
    'Coverage' => 'coverages',
    'Comments' => 'comentarios',
    'RecruitmentAd' => 'reclutamiento',
  }

  def self.translate_content_name(name, en2es = 1)
    name = name.downcase.normalize if en2es != 1
    translates = {'News' => 'noticias',
                  'Image' => 'imagenes',
                  'Download' => 'descargas',
                  'Demo' => 'demos',
                  'Topic' => 'topics',
                  'Blogentry' => 'entradas-de-blogs',
                  'Question' => 'preguntas',
                  'Poll' => 'encuestas',
                  'Bet' => 'apuestas',
                  'Event' => 'eventos',
                  'Tutorial' => 'tutoriales',
                  'Column' => 'columnas',
                  'RecruitmentAd' => 'anuncios-de-reclutamiento',
                  'Interview' => 'entrevistas',
                  'Review' => 'reviews',
                  'Funthing' => 'curiosidades',
                  'Coverage' => 'coverages',
                  'Comments' => 'comentarios',
    }

    if en2es == 1 then
      raise "#{name} not found" unless translates[name]
      translates.fetch(name) { |k| raise "IndexError (#{k} not found)" }
    else
      translates2 = {}
      translates.each { |k,v| translates2[v] = k }
      translates2.fetch(name) { |k| raise "IndexError (#{k} not found)" }

    end
  end

  @@comments_per_page = 30
  def self.comments_per_page
    @@comments_per_page
  end

  def self.comments_per_page= num
    @@comments_per_page = num
  end

  def self.gen_minicolumns(mode, data, dst_file)
    FileUtils.mkdir_p(File.dirname(dst_file)) unless File.exists?(File.dirname(dst_file))
    `#{App.python} script/spark.py #{mode} #{data.join(',')} "#{dst_file}"`
  end


  def self.min_hits_before_reaching_max_publishing_power(contents_type_name)
    case contents_type_name
      when 'Image':
      60
    else
      30
    end
  end

  def self.clans_contents_symbols
    @_cache_ccs ||= CLANS_CONTENTS.collect { |c| c.downcase.to_sym }
  end



  VALID_TITLE_REGEXP = /^([a-zA-ZáéíóúÁÉÍÓÚüëÜËñÑ0-9¿\?[:space:]\(\):;\.,_¡!\/&%"\+\-]+)$/i
  DNS_REGEXP = /^((?:[-a-zA-Z0-9]+\.)+[A-Za-z]{2,})$/i # no es perfecto
  URL_REGEXP = URI::regexp(%w(http https ftp))
  URL_REGEXP_FULL = /^(#{URI::regexp(%w(http https ftp))})$/ # /^(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?;+=&%@!\-\/]))?$/
  EMAIL_REGEXP = /^([^@\s]+)@((?:[-a-zA-Z0-9]+\.)+[A-Za-z]{2,})$/
  IP_REGEXP = /\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/


  def self.content_from_controller(name)
    t = {}
    CONTENTS_CONTROLLERS.each { |k,v| t[v] = k unless /Clans/ =~ k}
    t.fetch(name.downcase) { |k| raise "#{k} not found" }
  end

  def self.download_and_rewrite_bb_imgs(corpus, relative_savedir)
    known_domains = App.domain_aliases + [App.domain]
    corpus.gsub(/<img[^>]+src="([^"]+)"/i) do |rs|
      md = /http:\/\/([^\/]+)\/([^"]+)/i.match(rs)

      if md and not known_domains.include?(md[1].gsub('www.', '')) # remote download
        new_file = self.copy_image_to_dir(md[0], relative_savedir) # "#{self.class.name.downcase}/#{self.id % 1000}/#{self.id % 100}"

        if new_file.nil?
          rs
        else
          rs.gsub(md[0], new_file.gsub("#{Rails.root}/public", "http://#{App.domain}"))
        end
      else
        rs
      end
    end
  end

  # relative_savedir is relative to #{Rails.root}/public/storage/
  # Devuelve la ruta guardada o nil si no la ha podido guardar
  def self.copy_image_to_dir(imgurl, relative_savedir)
    if /http:\/\// =~ imgurl # download it first

      FileUtils.rm_rf("/tmp/gm_tmp_files/")
      tmpfile = "/tmp/gm_tmp_files/#{File.basename(imgurl).bare}"
      FileUtils.mkdir_p(File.dirname(tmpfile)) if not File.directory?(File.dirname(tmpfile)) # TODO clean this dir

      # using block
      File.open(tmpfile, 'w') do |f|
        f.binmode
        begin
          begin
           status = Timeout::timeout(5) {
              open(imgurl) { |str| f.write(str.read) }
           }
         rescue Exception => errdesc
              Rails.logger.warn(errdesc)
              return nil
           rescue Exception => errdesc
              Rails.logger.warn(errdesc)
             return nil
           end
        end
      end

      File.unlink(tmpfile) if File.size(tmpfile) == 0

      if File.exists?(tmpfile)
        begin
          img = Cms::read_image(tmpfile)
          raise Exception unless img
        rescue Exception => errdesc
          Rails.logger.warn("Imagen inválida: #{errdesc}")
          imgurl = nil
        else
          imgurl = tmpfile
        end
      end
    end

    # TODO añadir protección para no descargar archivos enormes

    return nil unless (!imgurl.nil?) and File.exists?(imgurl)

    self.unique_file_move_to_relative_savedir(imgurl, relative_savedir)
  end

  def self.unique_file_move_to_relative_savedir(src, relative_savedir)
    filename = File.basename(src).bare

    if File.exists?("#{Rails.root}/public/storage/#{relative_savedir}/#{filename}")
      incrementor = 1
      while File.exists?("#{Rails.root}/public/storage/#{relative_savedir}/#{incrementor}_#{filename}")
        incrementor += 1
      end
      dst = "#{Rails.root}/public/storage/#{relative_savedir}/#{incrementor}_#{filename}"
    else
      dst = "#{Rails.root}/public/storage/#{relative_savedir}/#{filename}"
    end

    FileUtils.mkdir_p(File.dirname(dst)) if not File.directory?(File.dirname(dst))
    FileUtils.cp(src, dst) if File.exists?(src)
    return dst
  end


  def self.parse_images(html_fragment, savedir)
    html_fragment = Cms.rails1_sanitize(html_fragment) if html_fragment.kind_of?(String)
    return html_fragment if html_fragment.nil? or not /<img / =~html_fragment
    known_domains = App.domain_aliases + [App.domain]

    # buscamos todos los tags imgs y los procesamos uno a uno para ver si el archivo es remoto o no o si es del dir del usuario
    html_fragment = html_fragment.gsub(/<img[^>]+src="([^"]+)"/i) do |frag|

      imgurl = /<img[^>]+src="([^"]+)"/i.match(frag).captures[0]
      md = /http:\/\/([^\/]+)\/(.+)/i.match(imgurl) # si no tiene slash después del hostname seguro que no es una imagen
      orig_imgurl = imgurl

      new_file = nil
      # puts "checking #{imgurl}"
      # TODO las imgs de urls con subdominio no las reconoce como propias
      if md and not known_domains.include?(md[1].gsub('www.', '')) # remote download
        new_file = self.copy_image_to_dir(imgurl, savedir)
        # puts new_file
      elsif /users_files/ =~ imgurl # users's file, copy it to the correct directory and rename it
        if md # quitamos el http://
          imgurl = "#{Rails.root}/public/#{URI::unescape(md[2])}" # TODO si la url es maliciosa? ../
        elsif !(/^\// =~ imgurl).nil?
          imgurl = "#{Rails.root}/public#{URI::unescape(imgurl)}"
        end
        # puts 'ble'
        new_file = self.copy_image_to_dir(imgurl, savedir)
        # puts "#{imgurl} #{savedir} #{new_file}"
      end

      if new_file.nil?
        frag
      else
        frag.gsub(orig_imgurl, new_file.gsub("#{Rails.root}/public", ''))
      end
    end



    # hacemos thumbnail de las imágenes locales (que hemos podido descargar) en las que el tamaño mostrado difiera  del original
    i = html_fragment.index(/<img([^>]+)src="([^"]+)"([^>]*)>/i)
    while !i.nil? and i < html_fragment.length
      ztr = html_fragment[i..-1]
      m = /(<img([^>]+)src="([^"]+)"([^>]*)>)/i.match(ztr)
      md = /http:\/\/([^\/]+)\/(.+)/i.match(m[3]) # si no tiene slash después del hostname seguro que no es una imagen
      if md # quitamos el http://
        imgurl = "#{Rails.root}/public/#{md[2]}" # TODO si la url es maliciosa? ../ > cuando intentemos cargar la imagen petará
      else
        imgurl = m[3]
      end

      # Todas las imágenes van a ser ahora o bien locales (con slash o con
      # http) o bien externas que no se pudieron descargar

      # comprobamos tamaño real y mostramos thumbnail si hay tamaño especificado distinto del original
      shown_w = nil
      shown_h = nil
      begin
        img = Cms::read_image("#{Rails.root}/public/#{imgurl}")
        raise ActiveRecord::RecordNotFound if img.nil?
      rescue Magick::ImageMagickError
      else
        [m[2], m[4]].each do |tag_part|
          # puts "tag_part: #{tag_part} from #{m[0]}"
          shown_w = /(width="([\d]+)px")/i.match(tag_part)[2].to_i if /(width="([\d]+)px")/i =~ tag_part
          shown_h = /(height="([\d]+)px")/i.match(tag_part)[2].to_i if /(height="([\d]+)px")/i =~ tag_part
          shown_w = /(width:[^\d]*([\d]+)px)/i.match(tag_part)[2].to_i if /(width:[^\d]*([\d]+)px)/i =~ tag_part
          shown_h = /(height:[^\d]*([\d]+)px)/i.match(tag_part)[2].to_i if /(height:[^\d]*([\d]+)px)/i =~ tag_part
        end
        # puts "(#{shown_w} and #{shown_w} != #{img.columns}) and (#{shown_h} and #{shown_h} != #{img.rows})"
        if (shown_w and shown_w != img.columns) and (shown_h and shown_h != img.rows) then
          html_fragment.gsub!(m[1], "<img src=\"/cache/thumbnails/f/#{shown_w}x#{shown_h}#{imgurl}\" />")
        end
      end

      i += 1
      i = html_fragment.index(/<img([^>]+)src="([^"]+)"([^>]*)>/i, i)
    end

    # 1. buscamos los imgs con tags <a alrededor suyo y los guardamos
    img_with_signatures_with_links= []
    frag = "#{html_fragment}"
    while frag.match(/<a[^>]+><img[^>]+src="\/cache\/thumbnails\/(f|k)\/([\d]+)x([\d]+)\/([^"]+)"[^>]*><\/a>/i)
      img_with_signatures_with_links<< frag.match(/<a[^>]+><img[^>]+src="\/cache\/thumbnails\/(f|k)\/([\d]+)x([\d]+)\/([^"]+)"[^>]*><\/a>/i)[0]
      frag = frag[(frag.index(/<a[^>]+><img[^>]+src="\/cache\/thumbnails\/(f|k)\/([\d]+)x([\d]+)\/([^"]+)"[^>]*><\/a>/i) + 1)..-1] # vamos avanzando
    end

    img_with_signatures_with_links.reverse!


    if img_with_signatures_with_links.size > 0 # hay imgs con cache y link alrededor a ignorar
      # 2. cortamos la cadena con los tags img con cache con link alrededor y substituimos en los interiores que encontramos
      new_html_fragment = ''
      html_fragment.split(/<a[^>]+><img[^>]+src="\/cache\/thumbnails\/[f|k]\/[\d]+x[\d]+\/[^"]+"[^>]*><\/a>/i).each do |fff|
        new_html_fragment<<  fff.gsub(/(<img[^>]+src="\/cache\/thumbnails\/(f|k)\/([\d]+)x([\d]+)\/([^"]+)"[^>]*>)/i, "<a href=\"/\\1\">\\0</a>")
        new_html_fragment<< img_with_signatures_with_links.pop if img_with_signatures_with_links.size > 0 # necesario porque para el último corte ya no nos quedarán trozos en la cadena
      end
      new_html_fragment<< img_with_signatures_with_links.pop if img_with_signatures_with_links.size > 0 # por si la cadena solo tiene el link
      html_fragment = new_html_fragment
    else # no hay imgs con cache y con links alrededor pero puede haber imgs con cache que necesiten link alrededor
      html_fragment.gsub!(/(<img[^>]+src="\/cache\/thumbnails\/(f|k)\/([\d]+)x([\d]+)\/([^"]+)"[^>]*>)/i, "<a href=\"/\\5\">\\1</a>")
    end

    #html_fragment.gsub(/color:\s*#[abcdef0-9]+)

    return html_fragment
  end


  # crea una thumbnail de una imagen src en dst.
  # width y height son enteros en px
  # mode puede ser:
  # - <tt>f</tt>: se resizea a exactamente las dimensiones dadas
  # - <tt>k</tt>: se mantienen las proporciones de la imagen
  # - <tt>i</tt>: modo inteligente
  def self.image_thumbnail(src, dst, width, height, mode, overwrite_existing=false)
    return if File.exists?(dst) and not overwrite_existing
    raise ActiveRecord::RecordNotFound if !File.exists?(src)

    FileUtils.mkdir_p(File.dirname(dst)) if !File.exists?(File.dirname(dst))

    begin
      img = Cms::read_image(src)
      raise ActiveRecord::RecordNotFound if img.nil?
    rescue Magick::ImageMagickError
      raise ActiveRecord::RecordNotFound
    else
      # si la imagen ya tiene las dimensiones necesarias solo copiamos al archivo thumbnail
      if width == img.columns and height == img.rows then
        FileUtils.cp(src, dst)
      else
        if mode == 'f' then # forzamos a este tamaño pase lo que pase
          thumb = img.thumbnail(width, height)
          thumb.write(dst)
        elsif mode == 'k' then # keep ratio
          if width >= img.columns and height >= img.rows then
            FileUtils::cp(src, dst)
          else
            new_width = ((img.columns * height) / img.rows).to_i

            if new_width > width
              new_width = width
              new_height = ((img.rows * width) / img.columns).to_i
            else
              new_height = height
            end
            thumb = img.thumbnail(new_width, new_height)
            thumb.write(dst)
          end # end resize

        elsif mode == 'i' then # extract square feature
          crop_img_to_square(img, width, height).write(dst)
        end # end mode
      end # make thumbnail if not same dimensions
    end # end no error
  end

  def self.crop_img_to_square(img, width, height)
    if height != width then
      # TODO esto falla muy fácilmente
      new_width = width
      new_height = height
      #img.crop_resized(new_width, new_height, gravity=Magick::CenterGravity).thumbnail(width, height)
      img.crop_resized(width, height, Magick::CenterGravity)
    else
      if img.columns > img.rows
        new_width = img.rows
        new_height = img.rows
      else
        new_width = img.columns
        new_height = img.columns
      end
      img.crop(Magick::CenterGravity, new_width, new_height).thumbnail(width, height)
    end
  end

  def self.clean_html(html_fragment)
    return html_fragment unless App.enable_tidy?
    return html_fragment if !(html_fragment.nil? or html_fragment.empty?)

    require 'tidy'
    opts = {:input_html => true,
      # opciones seguras
      :hide_comments => true,
      :logical_emphasis => true,
      :doctype => 'omit',
      :drop_font_tags => true,
      :drop_proprietary_attributes => true,
      :drop_empty_paras => false,
      :show_body_only => true,
      :wrap => 0,
      :join_styles => false,
      :force_output => true,

      # pueden ser peligrosas
      :bare => true,
      :clean => false,
      :quote_marks => true,
      :output_xhtml => true,
      :word_2000 => true
    }

    Tidy.path = App.tidy_path
    Tidy.open(opts) do |tidy|
      html_fragment = tidy.clean(html_fragment)
    end

    html_fragment.gsub!('<body>', '')
    html_fragment.gsub!('</body>', '')
    html_fragment.gsub!('<?xml version="1.0"?>', '')
    html_fragment.gsub!(/\n$/, '')
    html_fragment.gsub!(/\r$/, '')

    html_fragment
  end

  # TODO copypasted de file_colum para usar en modelo de facción
  def self.is_valid_upload(fileobj)
    # comprobamos path para archivos subidos en masa
    if fileobj.kind_of?(NilClass) or (fileobj.to_s != '' and \
     ((fileobj.respond_to?('original_filename') and fileobj.original_filename.bare.to_s != '') or (fileobj.respond_to?('path') && fileobj.path.to_s != ''))) then
      true
    end
  end

  def self.modify_content_state(content, user, new_state, reason=nil)
    raise AccessDenied if (user.id == content.user_id and not Cms::user_can_edit_content?(user, content))
    uniq = content.unique_content
    u_weight = Cms::get_user_weight_with(uniq.content_type, user, content)

    if u_weight == Infinity
      real_weight = 1.0
    else
      real_weight = u_weight
    end

    do_we_publish = (new_state == Cms::PUBLISHED) ? true : false
    pd = PublishingDecision.find(:first, :conditions => ['user_id = ? and content_id = ?', user.id, uniq.id])
    if pd then # ya había voto, actualizamos en lugar de crear
      pd.publish = do_we_publish
      pd.deny_reason = reason if !do_we_publish
      pd.accept_comment = reason if do_we_publish
      pd.user_weight = real_weight
      pd.save
    else
      base = {:user_id => user.id, :content_id => uniq.id, :publish => do_we_publish, :user_weight => real_weight}
      if do_we_publish
        base.merge!({ :accept_comment => reason })
      else
        base.merge!({ :deny_reason => reason })
      end
      pd = PublishingDecision.create(base)
    end
    prev_state = content.state
    if u_weight == Infinity # está votando un moderador, actualizamos campo 'is_right' de todos los publishing_decisions
      content.change_state(new_state, user)
      if new_state == Cms::DELETED && prev_state == PENDING then
        msg = "Lo lamentamos pero tu contenido ha sido denegado por las siguientes razones:\n\n"
        uniq.publishing_decisions.find(:all, :include => :user).each do |pd|
          msg<< "[~#{pd.user.login}]: #{pd.deny_reason}\n" if not pd.publish?
        end

        m = Message.new({ :message => msg, :sender => User.find_by_login('nagato'), :recipient => content.user, :title => "Contenido \"#{content.resolve_hid}\" denegado"})
        m.save
      end
    elsif PublishingDecision.find_sum_for_content(content) >= 1.0
      content.change_state(Cms::PUBLISHED, User.find_by_login('MrMan'))
      ttype, scope = SlogEntry.fill_ttype_and_scope_for_content_report(uniq)
      mrman = User.find_by_login('mrman')
      SlogEntry.create(:type_id => ttype, :scope => scope, :reporter_user_id => mrman.id, :headline => "#{Cms.faction_favicon(content)}<strong><a href=\"#{Routing.url_for_content_onlyurl(uniq.real_content)}\">#{uniq.real_content.resolve_html_hid}</a></strong> publicado") if prev_state == Cms::PENDING
    elsif PublishingDecision.find_sum_for_content(content) <= -1.0
      content.change_state(Cms::DELETED, User.find_by_login('MrMan'))
      msg = "Lo lamentamos pero tu contenido ha sido denegado por las siguientes razones:\n\n"
      uniq.publishing_decisions.find(:all, :include => :user).each do |pd|
        msg<< "[~#{pd.user.login}]: #{pd.deny_reason}\n" if not pd.publish?
      end

      ttype, scope = SlogEntry.fill_ttype_and_scope_for_content_report(uniq)
      mrman = User.find_by_login('mrman')
      SlogEntry.create(:type_id => ttype, :scope => scope, :reporter_user_id => mrman.id, :headline => "#{Cms.faction_favicon(content)}<strong><a href=\"#{Routing.url_for_content_onlyurl(uniq.real_content)}\">#{uniq.real_content.resolve_html_hid}</a></strong> denegado") if prev_state == Cms::PENDING

      m = Message.new({ :message => msg, :sender => User.find_by_login('nagato'), :recipient => content.user, :title => "Contenido \"#{content.resolve_hid}\" denegado"})
      m.save
    end

    if [Cms::PUBLISHED, Cms::DELETED].include?(content.state) then # actualizamos campo 'is_right' de todos los publishing_decisions ya que o bien un editor ha tomado una decisión o bien la suma de los pesos de las personas que han votado ya ha superado uno de los ratios
      uniq.publishing_decisions.find(:all).each do |pd|
        pd.is_right = ((content.state == Cms::PUBLISHED && pd.publish) || ((content.state == Cms::DELETED && !pd.publish))) ? true : false
        pd.save
        pd.personality.recalculate
      end

      #if content.state == Cms::PUBLISHED then
      #User.db_query("UPDATE publishing_decisions set is_right = publish WHERE content_id = #{uniq.id}")
      #else
      #User.db_query("UPDATE publishing_decisions set is_right = not publish WHERE content_id = #{uniq.id}")
      #end
    end
  end

  def self.publish_content(content, user, reason=nil)
    self.modify_content_state(content, user, Cms::PUBLISHED, reason)
  end

  def self.deny_content(content, user, reason)
    self.modify_content_state(content, user, Cms::DELETED, reason)
  end

  # Devuelve el peso de un usuario a la hora de moderar un contenido del tipo dado. En caso de superadmins o editores el peso es siempre Infinito
  def self.get_user_weight_with(content_type, user, content=nil)
    if user.has_admin_permission?(:capo) or (!content.nil? and Cms::user_can_edit_content?(user, content))
      Infinity
    else
      aciertos = User.db_query("SELECT count(a.id) FROM publishing_decisions A JOIN contents b ON a.content_id = b.id WHERE a.is_right = 't' AND b.content_type_id = #{content_type.id} AND a.user_id = #{user.id} AND a.created_on >= now() - '1 year'::interval")[0]['count'].to_i
      fallos = User.db_query("SELECT count(a.id) * 8 as count FROM publishing_decisions A JOIN contents b ON a.content_id = b.id WHERE a.is_right = 'f' AND b.content_type_id = #{content_type.id} AND a.user_id = #{user.id} AND A.created_on >= now() - '1 year'::interval")[0]['count'].to_i
      if fallos > aciertos
        #res = ((aciertos - fallos).abs.to_f / Cms::min_hits_before_reaching_max_publishing_power(content_type.name)) ** Math::E
        #res *= -1
        res = 0
      else
        res = ((aciertos - fallos).to_f / Cms::min_hits_before_reaching_max_publishing_power(content_type.name)) ** Math::E
        res = 0.99 if res >= 1.0
        res
      end
    end
  end

  def self.delete_content(content)
    content.state = Cms::DELETED
    content.save
  end

  def self.to_fqdn(str)
    str.bare.gsub('-', '').gsub('_', '').gsub('.', '')
  end


  def self.read_image(im)
    @@_images_read ||= 0
    @@_images_read += 1
    if @@_images_read >= 10
      @@_images_read = 0
      GC.enable
      GC.start
    end
    Magick::Image.read(im).first
  end

  def self.user_can_delete_content?(user, content)
    old = content.created_on
    content.created_on = 20.minutes.ago
    ret = user_can_edit_content?(user, content)
    content.created_on = old
    ret
  end

  def self.user_can_edit_content?(user, content)
    return false unless user && user.id

    #raise "(#{content.respond_to?(:state)} and #{content.user_id} == #{self.id} and #{content.state} == #{Cms::DRAFT})"
    if user.has_admin_permission?(:capo)
      true
    elsif (content.respond_to?(:state) and content.user_id == user.id and content.state == Cms::DRAFT) then
      true
    elsif (content.respond_to?(:state) and user.is_hq? and content.state == Cms::PENDING) then
      true
    elsif content.class.name == 'Question' && content.user_id == user.id && (content.created_on > 15.minutes.ago || content.unique_content.comments_count == 0)
      true
    elsif content.class.name == 'RecruitmentAd' && (user.has_admin_permission?(:capo) || user.id == content.user_id || (content.clan_id && content.clan.user_is_clanleader(user.id)))
      true
    elsif Cms::AUTHOR_CAN_EDIT_CONTENTS.include?(content.class.name) && content.user_id == user.id
      true
    elsif content.kind_of?(Coverage) && (c = content.event.competition) then
      c.user_is_admin(user.id) ? true : false
    elsif content.kind_of?(Coverage) then
      Cms::user_can_edit_content?(user, content.event)
    elsif content.class.name == 'Topic' or content.class.name == 'Comment' then
      # jefazo o moderador de la organization?
      # chequeamos que sea boss, underboss o moderador de la facción
      org = Organizations.find_by_content(content)
      # el autor del topic/comment y no está baneado
      if content.class.name == 'Topic' && user.id == content.user_id && content.created_on.to_i > 15.minutes.ago.to_i && (org.nil? || !org.user_is_banned?(content.user)) then
        true
      elsif org
        if org.user_is_moderator(user)
          true
        # TODO
        #elsif content.class.name == 'Topic' && (c = Competition.find_by_topics_category_id(content.main_category.id)) && c.user_is_admin(user.id)
        #  true
        elsif content.class.name == 'Comment'
          real = content.content.real_content
          # TODO
          #if real.class.name == 'Topic' && (c = Competition.find_by_topics_category_id(real.main_category.id)) && c.user_is_admin(user.id)
          #  true
          if real.class.name == 'Event' && (cm = CompetitionsMatch.find_by_event_id(real.id)) && cm.competition.user_is_admin(user.id)
            true
          else
            false
          end
        else # TODO Coverage
          false
        end
      else # categoría Otros o categoría GM
        if content.respond_to?(:content) && (real = content.content.real_content) && real.class.name == 'Coverage' && (c = Competition.find_by_event_id(real.event_id)) && c.user_is_admin(user.id)
          true
        else
          user.has_admin_permission?(:capo)
        end
      end
    else # editor o jefazo de organization?

      org = Organizations.find_by_content(content)
      if org
        org.user_is_editor_of_content_type?(user, ContentType.find_by_name(content.class.name))
      else
        false
      end
    end
  end

  def self.page_to_show(user, somecontent, objlastseen_on)
    objlastseen_on ||= Time.at(1)
    uniq_id = somecontent.unique_content.id
    tracker_item = TrackerItem.find(:first, :conditions => ['user_id = ? and content_id = ?', user.id, uniq_id])
    if tracker_item then
      comments_seen = Comment.db_query("SELECT count(id)
                                                       FROM comments
                                                      WHERE deleted = 'f'
                                                        AND content_id = #{uniq_id}
                                                        AND created_on <= to_timestamp('#{objlastseen_on.strftime('%Y%m%d%H%M%S')}',
                                                                                       'YYYYMMDDHH24MISS')")[0]
      page = ((comments_seen['count'].to_i + 1) / Cms.comments_per_page.to_f).to_f.ceil # le sumamos 1 porque queremos la página en la que está el primer comentario nuevo
      max = somecontent.cache_comments_count
      page = (max / Cms.comments_per_page.to_f).ceil if page > (max / Cms.comments_per_page.to_f).ceil
    else
      page = 1
    end

    page
  end

  def self.transform_content(original, dst_class, rpl_attributes={})
    # puts "Broken" # no funciona comments_count y se borra lo que no se debe, entre otras cosas
    # a la espera de unificar sistema de contenidos y que cambiar el tipo de contenidos sea simplemente cambiar un atributo y el karma
    original_updated_on = original.updated_on
    # Transforma el contenido dado a la clase de destino dada, lanza excepción si no puede
    # rpl_attributes debería tener atributos que dst_class requiere pero original no proporciona

    # creamos un nuevo objeto en modo NO PUBLICADO siempre
    # intercambios atributos comunes de tdas las clases
    # intercambios atributos comunes entre ellos
    attrs_new_obj = {}
    valid_attrs_to_copy = Cms::COMMON_CLASS_ATTRIBUTES + dst_class.new.unique_attributes.keys - [:id, :state]
    original.attributes.collect do |k,v|
      attrs_new_obj[k.to_sym] = v if valid_attrs_to_copy.include?(k.to_sym)
    end

    rpl_attributes.each do |k,v|
      raise "atributo #{k} ya esta definido!! valor: #{attrs_new_obj[k.to_sym]}" if attrs_new_obj[k.to_sym]
      attrs_new_obj[k.to_sym] = v if valid_attrs_to_copy.include?(k.to_sym)
    end

    attrs_new_obj.delete(:approved_by_user_id) unless dst_class.new.respond_to?(:approved_by_user_id)
    newinst = dst_class.new(attrs_new_obj)

    # newinst.terms = rpl_attributes[:terms] if rpl_attributes[:terms]

    raise newinst.errors.full_messages_html unless newinst.save
    newinst.log = original.log
    newinst.save # this will create additional log entry

    # actualizamos karma
    original.del_karma if original.state == Cms::PUBLISHED


    # intercambiamos los unique_content
    # puts "original.id: #{original.id}"
    origc_old = original.unique_content
    newc_old = newinst.unique_content
    # el primero es solo para evitar problemas con las constraints
    User.db_query("UPDATE contents set external_id = -1 WHERE id = #{origc_old.id}")

    User.db_query("UPDATE contents set content_type_id = #{origc_old.content_type_id}, external_id = #{origc_old.external_id} WHERE id = #{newc_old.id}")
    User.db_query("UPDATE contents set content_type_id = #{newc_old.content_type_id}, external_id = #{newc_old.external_id} WHERE id = #{origc_old.id}")
    # borramos el contenido viejo
    orig_state = original.state
    original.reload
    # original = original.class.find(original.id)
    Cms.delete_content(original)
    User.db_query("UPDATE #{ActiveSupport::Inflector::tableize(original.class.name)} SET unique_content_id = NULL WHERE id = #{original.id}")
    original.destroy

    # si el contenido viejo estaba en estado publicado publicamos el contenido nuevo
    # necesario para dar los gmfs y ajustar las caches
    if orig_state == Cms::PUBLISHED then
      newinst.change_state(Cms::PUBLISHED, User.find_by_login('mrman'))
    end
    User.db_query("UPDATE #{ActiveSupport::Inflector::tableize(newinst.class.name)} set updated_on = '#{original_updated_on}' WHERE id = #{newinst.id}")
    newinst.updated_on = original_updated_on
    newinst.unique_content.updated_on = original_updated_on
    User.db_query("UPDATE contents set updated_on = '#{original_updated_on}' WHERE id = #{newinst.unique_content.id}")
    uniq = newinst.unique_content
    uniq.url = nil
    Routing.gmurl(uniq)
    newinst
  end

  def self.user_can_mass_upload(u)
    u.is_hq || u.is_bigboss? || Faith.level(u) >= 2
  end

  def self.faction_favicon(thing)
    # TODO optimizar
    if thing.class.name == 'Faction'
      code = thing.code
      name = thing.name
    elsif thing.class.name == 'Game' then
      code = thing.code
      name = thing.name
    elsif thing.class.name == 'Platform' then
      code = thing.code
      name = thing.name
    elsif thing.class.name == 'User' then
      if thing.faction then
        code = thing.faction.code
        name = thing.faction.name
      else
        code = name = nil
      end
    elsif thing.class.name == 'String' then
      code = thing
      name = thing
    elsif thing.class.name == 'BazarDistrict'
      code = thing.code
      name = thing.name
    elsif thing.class.name == 'Funthing'
      code = 'bazar'
      name = 'bazar'
    elsif thing.class.name == 'Term'
      g = nil
      %w(game platform bazar_district clan).each do |posattr|
        if thing.send("#{posattr}_id".to_sym)
          g = thing.send(posattr.to_sym)
          code = g.code
          name = g.name
          break
        end
      end
      if g.nil? || g.code == 'gmversion'
        code = 'gm'
        name = 'gm'
      end
    else # es categoría o contenido
      if thing.class.name == 'Content' then
        thing = thing.real_content
      end
      if /Category/ =~ thing.class.name then
        #
      elsif Cms::CONTENTS_WITH_CATEGORIES.include?(thing.class.name) # si es contenido con categoría buscamos la categoría
        thing = thing.main_category
      else
        thing = nil
      end

      if thing.nil?
        code = 'gm'
        name = 'gm'
      elsif thing.id == thing.root_id then
        code = thing.code
        name = thing.name
      else
        code = thing.root.code
        name = thing.root.name
      end
    end

    return if code.nil?

    src = 'games'
    "<img class=\"factionfavicon gs-#{code}\" title=\"#{name}\" src=\"/images/blank.gif\" />"
  end

  VERBOTEN_TAGS = %w(form script plaintext u applet iframe) unless defined?(VERBOTEN_TAGS)
  VERBOTEN_ATTRS_REGEXP = /^on/i unless defined?(VERBOTEN_ATTRS_REGEXP)
  #VERBOTEN_ATTRS = %w()

  def self.rails1_sanitize(html)
    # only do this if absolutely necessary
    if html.index("<")
      tokenizer = HTML::Tokenizer.new(html)
      new_text = ""

      while token = tokenizer.next
        node = HTML::Node.parse(nil, 0, 0, token, false)
        new_text << case node
          when HTML::Tag
          if VERBOTEN_TAGS.include?(node.name)
            node.to_s.gsub(/</, "&lt;")
          else
            if node.closing != :close
              node.attributes.delete_if { |attr,v| attr =~ VERBOTEN_ATTRS_REGEXP }
              %w(href src).each do |attr|
                node.attributes.delete attr if node.attributes[attr] =~ /^javascript:/i
              end
            end
            node.to_s
          end
        else
          node.to_s.gsub(/</, "&lt;")
        end
      end

      html = new_text
    end

    html
  end

  def self.add_p(text)
    return text if text.nil?
    # Añade tags p al texto en cuestión
    textc = "#{text}"
    ntext = ""
    # Los paras suponemos que estan separados por <br />
    textc.gsub!("<br>", "<br />")
    #textc.gsub!("<br />", "</p><p>")
    # text << "\n" if text.index("\n") == -^
    # text = text.gsub("\r", "\n").gsub("\n\n", "\n")
    textc.split("<br />").each do |para|
      if para.index('<p>') && para.index('<p>') > 0 && para[0..0] != '<' # hay un \n, tipico parrafo inicial sin p y resto con p
        ntext << "<p>#{para.split("<p>")[0].strip}</p>\n<p>#{para.split("<p>")[1]}"
      elsif para.index('<p>').nil?
        ntext << "<p>#{para.strip}</p>\n"
      else
        ntext << para.gsub("<p>\n", "<p>")
      end
    end
    ntext = "<p>#{ntext}</p>" if ntext.index("<").nil?
    ntext.gsub!('<p></p>', '')
    ntext.strip
  end

  def self.get_unique_portal_code(code)
    i = ''
    if Portal.find_by_code(code) || Portal::UNALLOWED_CODES.include?(code)
      i = 1
      while Portal.find_by_code("#{code}#{i}") || Portal::UNALLOWED_CODES.include?(code)
        i += 1
      end
    end
    code
  end

  def self.user_can_select_best_answer(user, content)
    content.class.name == 'Question' && (Cms::user_can_edit_content?(user, content) || user.id == content.user_id)
  end

  def self.user_can_create_content(user)
    User::STATES_CAN_LOGIN.include?(user.state) && user.antiflood_level < 5
  end

  def self.can_edit_term?(u, term, taxonomy)
    self.can_admin_term?(u, term, taxonomy) && term.id != term.root_id
  end

  def self.can_admin_term?(u, term, taxonomy)
    return true if u.has_admin_permission?(:capo)

    if term.game_id
      f = Faction.find_by_code(term.game.code)
      f.is_bigboss?(u) || f.user_is_editor_of_content_type?(u, ContentType.find_by_name(taxonomy))
    elsif term.platform_id
      f = Faction.find_by_code(term.platform.code)
      f.is_bigboss?(u) || f.user_is_editor_of_content_type?(u, ContentType.find_by_name(taxonomy))
    elsif term.bazar_district_id
      f = term.bazar_district
      f.is_bigboss?(u) || f.is_sicario?(u)
    elsif term.clan_id
      c = term.clan
      c.user_is_clanleader(u)
    end
  end

  def self.get_editable_terms_by_group(u)
    terms = {:games => [], :platforms => [], :clans => [], :bazar_districts => [], :special => []}

    if u.has_admin_permission?(:capo)
      Term.top_level(:conditions => 'taxonomy <> \'ContentsTag\'').each do |t|
        if t.game_id
          terms[:games] << t
        elsif t.platform_id
          terms[:platforms] << t
        elsif t.clan_id.nil? && t.bazar_district_id.nil? && t.taxonomy.nil?
          terms[:special] << t
        end
      end
    end

    if u.has_admin_permission?(:bazar_manager)
      Term.find(:all, :conditions => 'id = root_id AND bazar_district_id IS NOT NULL').each do |t|
        terms[:bazar_districts] << t
      end
    end

    u.users_roles.find(:all, :conditions => "role IN ('Boss', 'Underboss')").each do |ur|
      f = Faction.find(ur.role_data.to_i)
      t = f.single_toplevel_term
      if t.game_id
        terms[:games] << t
      else
        terms[:platforms] << t
      end
    end

    u.users_roles.find(:all, :conditions => "role = 'Editor'").each do |ur|
      f = Faction.find(ur.role_data_yaml[:faction_id])
      t = f.single_toplevel_term
      if t.game_id
        terms[:games] << t
      else
        terms[:platforms] << t
      end
    end

    u.users_roles.find(:all, :conditions => "role IN ('Don', 'ManoDerecha', 'Sicario')").each do |ur|
      terms[:bazar_districts] << BazarDistrict.find(ur.role_data.to_i).top_level_category
    end

    [:games, :platforms, :special, :bazar_districts].each do |sym|
      terms[sym].uniq!
      # terms[sym].sort {|a,b| a.name.downcase <=> b.code.name.downcase }
    end

    terms
  end
end
