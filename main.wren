import "graphics" for Canvas, Color
import "random" for Random
import "dome" for Window, Process
import "math" for M, Vec
import "input" for Keyboard
import "audio" for AudioEngine
import "./keys" for Key

var BIT_RATE = 44100

var R = Random.new()
var D_PI = Num.pi / 180

var LEFT_KEY = Key.new("left", false, -1)
var RIGHT_KEY = Key.new("right", false, 1)
var SPACE_KEY = Key.new("space", false, true)

class Beat {
  construct new(position, action) {
    _position = position
    _action = action
    _hit = false
    _miss = false
  }

  hit() {
    _hit = true
  }
  miss() {
    _miss = true
  }

  hit { _hit }
  miss { _miss }
  action { _action }
  position { _position }
}


var BEATS = {}
var side = 1
for (n in 4...100) {
  var q = n * 4
  side = R.int(3)
  BEATS[q] = Beat.new(q, side)
}
/*
var BEAT_MAP = {
  5: [null, null, Beat.new(5)]
}
*/



class Song {
  construct new() {}
}

class Conductor {
  construct new(audio) {
    _bpm = 160
    _crotchet = 60 / _bpm //sec per beat
    _position = 0
    _beatPosition = 0
    _audio = audio
    _length = audio.length / BIT_RATE
  }


  update() {
    _position = M.mid(0, (_audio.position / BIT_RATE), _length) // position in seconds
    _beatPosition = _position / _crotchet
  }

  position { _position }
  length { _length }
  beatPosition { _beatPosition }
}

class Decoration {
  update() {}
  draw(n) {}
}

var COLS = [
  Color.white,
  Color.darkgray
]

class SpaceLine is Decoration {
  construct new(pos, dir) {
    _original = pos
    _pos = pos
    _dir = dir.unit
    _len = 0
    _color = R.sample(COLS)
  }

  update() {
    if (_pos.x < 0 || _pos.x >= Canvas.width || _pos.y < 0 || _pos.y >= Canvas.height) {
      _pos = _original
      var theta = (-90 + R.int(280) - 140) * D_PI
      _dir = Vec.new(M.cos(theta), M.sin(theta))
    } else {
      _pos = _pos + _dir * 2
    }
    _len = M.mid(0, _len + 1, 40)
  }

  draw(n) {
    var dest = _pos + _dir * _len
    var color = _color
    /*
    if (_pos.y > (Canvas.height / 4) * 2) {
      color = _color
    }
    */
    Canvas.line(_pos.x, _pos.y, dest.x, dest.y, color)
  }

}

class Game {
    static init() {
      __flash = 0
      __charge = 0
      __score = 0
      __misses = 0
      Canvas.resize(320, 180)
      var scale = 3
      Window.resize(scale * Canvas.width, scale * Canvas.height)
      __oldX = 0
      __x = 0
      __tweenX = 0
      // AudioEngine.load("music", "extremeaction.ogg")
      // AudioEngine.load("music", "click.ogg")
      AudioEngine.load("music", "race-to-mars.ogg")
      var channel = AudioEngine.play("music")
      __conductor = Conductor.new(channel)

      var centerX = Canvas.width / 2
      var centerY = Canvas.height / 4
      var center = Vec.new(centerX, centerY)
      __decorations = (1...40).map {|n|
        var theta = (-90 + R.int(280) - 140) * D_PI
        return SpaceLine.new(center, Vec.new(M.cos(theta), M.sin(theta)))
      }.toList
    }
    static update() {
      __decorations.each {|decor| decor.update() }
      __tweenX = M.mid(0, __tweenX + 0.34, 1)
      if (Keyboard.isKeyDown("escape")) {
        Process.exit()
      }
      LEFT_KEY.update()
      RIGHT_KEY.update()
      SPACE_KEY.update()
      __conductor.update()

      if (LEFT_KEY.firing) {
        __oldX = __x
        __tweenX = 0
        __x = __x + LEFT_KEY.action
      } else if (RIGHT_KEY.firing) {
        __oldX = __x
        __tweenX = 0
        __x = __x + RIGHT_KEY.action
      }

      __x = M.mid(-1, __x, 1)
      var notePosition = __x + 1
      if (__flash) {
        __flash = M.max(0, __flash - 1)
      }
      var soon = ((__conductor.beatPosition.floor - 1)...(__conductor.beatPosition.floor + 5)).map {|n| BEATS[n] }
      // if (SPACE_KEY.firing) {
        var hit = false
        for (beat in soon) {
          if (beat != null) {
            var margin = (beat.position - __conductor.beatPosition)
            var absMargin = margin.abs
            if (!beat.hit && absMargin < 0.5 && beat.action == notePosition) {
              beat.hit()
              hit = true
              System.print(margin)
              if (absMargin < 0.1) {
                __score = __score + 5
                __charge = __charge + 3
                __flash = 3
              } else if (absMargin < 0.3) {
                __score = __score + 3
                __charge = __charge + 1
                __flash = 3
              } else if (absMargin < 0.5) {
                __score = __score + 1
                __flash = 3
              }
            }
          }
        }
        /*
        if (!hit) {
          __misses = __misses + 1
          __charge = M.max(0, __charge - 5)
        }
      }
        */
      for (beat in soon) {
        if (beat != null) {
          var margin = (beat.position - __conductor.beatPosition)
          if (margin < -1  && !beat.hit && !beat.miss) {
            beat.miss()
            __misses = __misses + 1
            __charge = M.max(0, __charge - 3)
          }
        }
      }
    }
    static draw(dt) {
      Canvas.cls()
      __decorations.each {|decor| decor.draw(dt) }

      var width = 60
      var height = 17
      var spacing = 32

      var centerX = Canvas.width / 2
      var centerY = Canvas.height / 4
      var center = Vec.new(centerX, centerY)

      var playerY = Canvas.height - 2 - height - 9

      var lineY = playerY + height / 2 - 1
      Canvas.line(0, lineY, Canvas.width, lineY, Color.purple)
      Canvas.line(centerX, centerY, centerX, Canvas.height, Color.white)
      Canvas.circlefill(center.x, center.y, 12, Color.white)
      var beatDiff = (__conductor.beatPosition - __conductor.beatPosition.floor).abs
      for (n in 0...5) {
        Canvas.circle(center.x, center.y, (12 + beatDiff * 4 * n).floor, n <= 3 ? Color.white : Color.lightgray)
      }
      var centerLeft = Vec.new(centerX - 4, centerY)
      var centerRight = Vec.new(centerX + 4, centerY)
      var centerTarget = Vec.new(centerX, lineY)
      var leftTarget = Vec.new(centerX - (width + spacing), lineY)
      var rightTarget = Vec.new(centerX + (width + spacing), lineY)
      var result = leftTarget + (leftTarget - centerLeft)
      Canvas.line(centerLeft.x, centerLeft.y, result.x, result.y, Color.white)
      result = rightTarget + (rightTarget - centerRight)
      Canvas.line(centerRight.x, centerRight.y, result.x, result.y, Color.white)


      var soon = ((__conductor.beatPosition.floor - 3)...(__conductor.beatPosition.floor + 10)).map {|n| BEATS[n] }
      for (beat in soon) {
        if (beat != null) {
          var beatPos = (beat.position - __conductor.beatPosition)
          var target
          var origin
          if (beat.action == 0) {
            target = leftTarget
            origin = centerLeft
          } else if (beat.action == 1) {
            target = centerTarget
            origin = center
          } else if (beat.action == 2) {
            target = rightTarget
            origin = centerRight
          }

          var direction = (target - origin).unit
          var pos = target - direction * beatPos * 15
          if (beatPos <= 10 && pos.y >= origin.y) {
            var radius = M.mid(8, 9 - beatPos, 1)
            if (beat.hit) {
              Canvas.circle(pos.x, pos.y, radius, Color.green)
            } else {
              Canvas.circlefill(pos.x, pos.y, radius, Color.green)
            }
          }
        }
      }

      var x = M.lerp(__oldX, __tweenX, __x)

      Canvas.rectfill(centerX + x * (width + spacing) - (width / 2), playerY, width, height, __flash > 0 ? Color.white : Color.red)

      var secs = __conductor.length - __conductor.position
      var mins = (secs / 60).floor
      secs = (secs % 60)
      var msecs = ((secs - secs.floor) * 10).toString[0]
      secs = secs.floor
      if (mins < 9) {
        mins = "0%(mins)"
      }
      if (secs < 9) {
        secs = "0%(secs)"
      }

      if (__charge > 0) {
        var color = Color.green
        Canvas.rectfill(center.x + 1, 0, __charge, 8, color)
        Canvas.rectfill(center.x - __charge, 0, __charge, 8, color)
        Canvas.line(center.x - __charge, 8, center.x + __charge, 8, Color.white)
      }

      Canvas.print("Score: %(__score)", 0, 0, Color.white)
      Canvas.print("Misses: %(__misses)", 0, 8, Color.white)
      Canvas.print("Time %(mins):%(secs):%(msecs)", 0, 16, Color.white)
    }
}
