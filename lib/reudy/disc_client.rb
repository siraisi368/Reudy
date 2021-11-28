
require 'socket'
require 'thread'
require 'discordrb'
require_relative 'reudy_common'

module Gimite


  class DiscordBot
    include Gimite
    SILENT_SECOND = 20.0 #沈黙が続いたと判断する秒数。
    def initialize(user, logOut = STDOUT)
      @token = user.settings[:disc_token] #BOTトークンを取得
      @user = user #Reudyオブジェクトを設定
      @bot = Discordrb::Bot.new(token: @token) #Discordクライアントオブジェクト
      @user.client = self
      @queue = Queue.new
      @prevTime = Time.now #onSilent用。
      @chid = nil
      @logid = nil
      @now_message = nil
      @now_channel = nil
      @isExitting = nil
      threads = []
      threads << Thread.new { processLoop(@token) }
      threads << Thread.fork { message_shori() }
      threads.each { |thr| thr.join }
    end



    def status=(status)
    end

    #exitがないってエラーの対策
    def exit
      puts "終了"
    end

    #@queueのメッセージを処理する
    def message_shori
      loop do
        sleep(@user.settings[:wait_before_speak].to_f * (0.5 + rand)) if @user.settings[:wait_before_speak]
        if !@queue.empty?
          args = @queue.pop
          if @queue.empty?
            @user.onOtherSpeak(*(args + [false]))
          else
            @user.onOtherSpeak(*(args + [true]))
          end
        end
        time = Time.now
        if time - @prevTime >= SILENT_SECOND
          puts "沈黙を検知"
          @prevTime = time
          @user.onSilent
        end
      end
    end

    #発言
    def speak(s)
      puts "メッセージ: #{s}"
      if @now_channel != nil
        @now_channel.start_typing()
      end
      if s.length / (@user.mode * 1.6) <= 7
        sleep(s.length / (@user.mode * 1.6))
      else
        sleep(7)
      end

      @now_channel.send(s)
    end

    #実行可能なコマンドを実行
    def command(s)
      puts "コマンド: #{s}"
      if s =~ /!command disc_change (.+)/
        result = @bot.find_channel($1)
        unless result == {} || result == []
          @now_channel = result[0]
          return true
        end
      end
      return false
    end

    #ログを出力
    def outputInfo(x)
      if @user.settings[:teacher_mode]
        puts x
        @log_channel.send(x)
      else
        puts x
      end
    end

    #botの重要なプロセス。
    #メッセージを受信。
    def processLoop(token)
      puts "プロセススタート"
      @chid = @user.settings[:disc_channel]
      @log = @user.settings[:disc_log]
      # サーバから受け取ったメッセージを処理
      @bot.message do |event|
        unless event.message.content == ''
          if event.channel.id != @logid && (event.channel.id == @chid || @user.settings[:nicks].any? {|n| event.message.content.include?(n)} || event.channel.type == 1)
            if event.channel.id != @chid
              @user.onDiscChange(event.channel.name, event.user.name)
            end
            @chid = event.channel.id
            @now_message = event.message
            @now_channel = event.channel
            puts "> メッセージ受信： #{event.message.content}"
            abc = event.message.content.gsub(/\R/, "　").gsub(/<@(.*?)> /, "お客さん").gsub(/ <@(.*?)>/, "お客さん").gsub(/ <@(.*?)> /, "お客さん").gsub(/<@(.*?)>/, "お客さん").gsub(/@here/, "みんな").gsub(/@everyone/, "みんな")
            @prevTime = Time.now
            @queue.push([event.user.name, abc])
          elsif event.channel.id == @logid
            puts "> コンソール受信： #{event.message.content}"
            @user.onControlMsg(event.message.content)
            @log_message = event.message
          else
            if @user.settings[:teacher_mode]
              if event.message.content =~ /!#{@user.settings[:nick]} setup console/ || event.message.content =~ /!#{@user.settings[:nick]} sc/
                @log_message = event.message
                @log_channel = event.channel
                @logid = event.channel.id
                @log_message.reply!("complited setup successful")
              end
            end
          end
        end
      end
      @bot.run
    end

  end
end
