extends Node

@onready var sfx: Node = $SFX

# 音乐文件夹路径，根据你的实际项目结构调整
var music_folder_path1 = "res://sound/musics/"
var music_folder_path2 = "user://sound/musics/"
# 存储加载的音乐流
const bgm1 = preload("uid://bktkye4maby1l")
const bgm2 = preload("uid://bonqc8yki7dsd")
const bgm3 = preload("uid://tx34l6yy4rkt")
const bgm4 = preload("uid://beq54rd0kh2ew")

var music_streams: Array[AudioStream] = []
# 当前播放的音乐索引
var current_index: int = -1

@onready var audio_player: AudioStreamPlayer = $SFX/BGM

func play_sfx(name : String) -> void:
	var player := sfx.get_node(name) as AudioStreamPlayer
	if not player:
		return
	player.play()
	
# 播放高亮音效的函数
func play_button_grab():
	play_sfx("ButtonGrab")

# 播放点击音效的函数
func play_button_click():
	play_sfx("ButtonPressed")

func _ready():
	# 加载音乐文件
	#load_music_files(music_folder_path1)
	#if music_streams.size()==0:
		#load_music_files(music_folder_path2)
	
	var b1: AudioStream = bgm1
	music_streams.append(b1)
	var b2: AudioStream = bgm2
	music_streams.append(b2)
	var b3: AudioStream = bgm3
	music_streams.append(b3)
	var b4: AudioStream = bgm4
	music_streams.append(b4)
		
	# 连接播放结束信号
	audio_player.finished.connect(_on_audio_finished)

# 加载音乐文件夹中的文件
func load_music_files(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# 跳过文件夹
			if not dir.current_is_dir():
				# 检查文件扩展名，根据需要添加或删除
				if file_name.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
					var file_path = path.path_join(file_name)
					var stream: AudioStream = load(file_path)
					if stream:
						music_streams.append(stream)
						print("加载音乐: ", file_name)
					else:
						push_error("加载失败: " + file_name)
			file_name = dir.get_next()
	else:
		push_error("无法打开目录: " + path)

# 播放随机音乐
func play_random_music():
	if music_streams.is_empty():
		push_warning("没有加载任何音乐文件。")
		return
	
	# 随机选择一个与当前不同的索引 (如果有多首音乐)
	var new_index = current_index
	if music_streams.size() > 1:
		while new_index == current_index:
			new_index = randi() % music_streams.size()
	else:
		new_index = 0  # 如果只有一首歌，直接播放
	
	current_index = new_index
	audio_player.stream = music_streams[current_index]
	audio_player.play()
	audio_player.volume_db=-5
	print("正在播放: ", current_index)

# 停止bgm
func stop_music():
	audio_player.stop()

# 当一首音乐播放结束时，播放下一首
func _on_audio_finished():
	play_random_music()
