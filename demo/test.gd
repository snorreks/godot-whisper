extends Node2D

@export var interval := 5.0
@export var keep_interval := 2.0
@export var text := ""
@export var tokens: Array
@onready var idx = AudioServer.get_bus_index("Record")
@onready var effect_capture := AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
@onready var speech_to_text : SpeechToText = $SpeechToText
var buffer_full : PackedVector2Array

func _ready():
	if effect_capture.buffer_length < interval:
		push_warning("buffer_length smaller than interval.")
		interval = effect_capture.buffer_length
	speech_to_text.duration_ms = int(interval * 1000)

func merge_with_old_tokens(new_tokens: Array):
	var offset : int = (interval - keep_interval / 2) * 100
	var offset_reverse : int = keep_interval / 2 * 100
	var last_word_deleted := ""
	for i in range(tokens.size()-1, -1, -1):
		# remove from here as they are positive
		if tokens[i]["t0"] - offset < 0:
			tokens = tokens.slice(0, i + 1)
			last_word_deleted = tokens[i]["text"]
			break
	tokens_to_text(tokens)
	tokens_to_text(new_tokens)
	print(last_word_deleted)
	for i in range(new_tokens.size()):
		# remove from here as they are positive
		if new_tokens[i]["t0"] - offset_reverse > 0:
			new_tokens = new_tokens.slice(i)
			break
	tokens_to_text(new_tokens)
	tokens.append_array(new_tokens)
	

func tokens_to_text(tokens):
	text = ""
	for token in tokens:
		text += token["text"]
	print("Text: ... ", text, " ...")

func _thread_function(buffer_full):
	var new_tokens :Array= speech_to_text.transcribe(buffer_full)
	new_tokens = new_tokens.filter(func (token): return !("[" in token["text"]) && !("<" in token["text"]))
	if !tokens.is_empty():
		merge_with_old_tokens(new_tokens)
	else:
		tokens = new_tokens
	tokens_to_text(tokens)

func _process(_delta):
	var buffer: PackedVector2Array = effect_capture.get_buffer(effect_capture.get_frames_available())
	buffer_full.append_array(buffer)
	var mix_rate : int = ProjectSettings.get_setting("audio/driver/mix_rate")
	var total_len : int = mix_rate * interval
	var keep_len : int = mix_rate * keep_interval
	if buffer_full.size() > total_len:
		buffer_full.slice(buffer_full.size() - total_len)
		var thread = Thread.new()
		thread.start(_thread_function.bind(buffer_full.duplicate()))
		buffer_full = buffer_full.slice(buffer_full.size() - keep_len, buffer_full.size())
