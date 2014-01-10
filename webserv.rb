require 'socket'

class HttpServer
  def initialize(session, request, pwd)
    @session = session
    @request = request
    @pwd = pwd

    #Content-Length로 가져온 값을 저장할 스트링
    @formcontent = ""
  end

  def formparse(buffer)
    #html 코드(예제 = action.html) 상에서 특정 문자열 위치에 가져온 값을 파싱하여 코드에 삽입
    indexstring = "<p>an empty stub</p>"
    
    if buffer.gsub!(indexstring)
      @formcontent.split('&').each do |form|
        buffer.gsub!(indexstring,"<h3>"+form.split('=')[0]+" : "+form.split('=')[1]+"</h3>"+indexstring)
      end

      buffer.gsub!(indexstring,'')
    end
    
    return buffer
  end

  def parse()
    fileName = nil
    readline = nil
    cont_len = nil
    
    # POST메소드로 넘겨받은 값을 Content-Length를 가지고 세션에서 form data를 분리
    if @request =~ /POST .* HTTP.*/
      loop do
        readline = @session.gets.strip
        cont_len = readline.gsub(/Content-Length: /,'').to_i if readline =~ /Content-Length: .*/
        
        if readline.length == 0
          cont_len.times do
            @formcontent << @session.getc
          end
          
          break
        end
      end
    end

    # 세션에서 가져온 리퀘스트의 메서드와 http프로토콜 규격에서 웹서버가 가져올 파일 이름을 추출
    if @request =~ /GET .* HTTP.*/ or @request =~ /POST .* HTTP.*/
      fileName = @request.gsub(/GET /, '').gsub(/POST /, '').gsub(/ HTTP.*/, '')
    end

    # 파일명에서 \n 문자 제거 및 요청하는 파일명을 현재 경로와 합쳐줌
    # strip은 trim과 거의 같은 기능을 수행
    fileName = @pwd + fileName.strip

    #요청하는 경로 == 폴더일때 index.html을 파일 이름에 추가해줌
    fileName << "index.html" if File.directory?(fileName)

    return fileName
  end

  def start()
    @fullPath = parse()
    src = nil
    begin
      if File.file?(@fullPath)
        if @fullPath.index(@pwd) == 0
          contentType = getContentType(@fullPath)         
          @session.print "HTTP/1.1 200/OK\nContent-type: #{contentType}\r\n\r\n"
          
          #256바이트 기준으로 웹서버가 버퍼에 읽어들이고 기록함
          src = File.open(@fullPath, "rb")
          while (not src.eof?)
            buffer = src.read(256)

            #가져온 form 값을 파싱해 html 코드(test03예제 action.html)로 추가
            buffer = formparse(buffer)
            @session.write(buffer)
          end
        else
          #파일은 존재하나 잘못된 접근
          @session.print "HTTP/1.1 403/Forbidden access"
        end
      else
        #파일이 존재하지 않거나 올바른 파일이 아님
        @session.print "HTTP/1.1 404/Object Not Found"
      end
    rescue
      puts "File Process Error"
    ensure
      src.close unless src == nil
      @session.close
    end
  end

  def getContentType(path)
    ext = File.extname(path) # 확장자만 추출
    
    #이미지 반환
    return "image/jpeg" if ext == ".jpeg" or ext == ".jpg"
    return "image/gif"  if ext == ".gif"
    return "image/png"  if ext == ".png"
    return "image/bmp"  if ext == ".bmp"

    #텍스트 및 기타 웹 파일 반환
    return "text/html"       if ext == ".html" or ext == ".htm"
    return "text/plain"      if ext == ".txt"
    return "text/css"        if ext == ".css"
    return "text/javascript" if ext == ".js"

    return "text/plain" if ext == ".rb"
    return "text/xml"   if ext == ".xml"
    return "text/xml"   if ext == ".xsl"
    
    return "text/html"
  end
end

server = TCPServer.new('127.0.0.1', 9090)
dirname = File.dirname($0) # "./", Dir.getwd, Dir::pwd도 가능하나 유연성을 고려하여 변경
pwd = File.expand_path(dirname, @defaultPath) # 원격 경로에서도 웹서버 실행 가능하게끔 개선

loop do
  session = server.accept # 서버 접속 시도(성공)를 수용함
  request = session.gets # 연결로부터 요청하는 형식과 메소드, 규약 등을 받아옴
  
  Thread.start(session, request) do |session, request|
    HttpServer.new(session, request, pwd).start()
  end
end