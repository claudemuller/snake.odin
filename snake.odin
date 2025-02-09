package snake

import "core:fmt"
import "core:log"
import "core:math"
import rl "vendor:raylib"

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE

GAMEPAD_LIMIT :: 0.2
TICK_RATE :: 0.13

CAMERA_SHAKE_MAGNITUDE :: 5.0
CAMERA_SHAKE_DURATION :: 15

MAX_SNAKE_LEN :: GRID_WIDTH * GRID_WIDTH
INIT_SNAKE_LEN :: 3

PURPLEISH :: [4]u8{39, 39, 68, 255}
LIGHT_PURPLEISH :: [4]u8{73, 77, 126, 255}
DARK_PURPLEISH :: [4]u8{22, 22, 46, 255}

Vec2i :: [2]i8

UI :: struct {
	str:   cstring,
	size:  i32,
	width: i32,
}

GameState :: struct {
	snake:                 struct {
		len:       u16,
		body:      [MAX_SNAKE_LEN]Vec2i,
		direction: Vec2i,
	},
	food_pos:              Vec2i,
	sounds:                struct {
		eat:   rl.Sound,
		crash: rl.Sound,
	},
	textures:              struct {
		head: rl.Texture,
		body: rl.Texture,
		tail: rl.Texture,
		food: rl.Texture,
	},
	ui:                    struct {
		game_over:    UI,
		new_game_ins: UI,
	},
	keys:                  struct {
		restart_down: bool,
	},
	camera:                rl.Camera2D,
	camera_shake_duration: f32,
	score:                 u8,
	high_score:            u8,
	tick_timer:            f32,
	game_over:             bool,
}

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake")
	rl.InitAudioDevice()

	state: GameState
	init(&state)
	restart(&state)

	for !rl.WindowShouldClose() {
		process_input(&state)

		update(&state)

		rl.BeginDrawing()
		rl.ClearBackground(PURPLEISH.rgba)
		rl.BeginMode2D(state.camera)

		render(&state)

		rl.EndMode2D()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	stop(&state)
}

init :: proc(state: ^GameState) {
	state.camera = rl.Camera2D {
		zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,
	}

	state.tick_timer = TICK_RATE

	state.ui.game_over.str = cstring("Game Over")
	state.ui.game_over.size = i32(25)
	state.ui.game_over.width = rl.MeasureText(state.ui.game_over.str, state.ui.game_over.size)
	state.ui.new_game_ins.str = cstring("Press enter to play again")
	state.ui.new_game_ins.size = i32(15)
	state.ui.new_game_ins.width = rl.MeasureText(
		state.ui.new_game_ins.str,
		state.ui.new_game_ins.size,
	)

	state.textures.food = rl.LoadTexture("res/food.png")
	state.textures.head = rl.LoadTexture("res/head.png")
	state.textures.body = rl.LoadTexture("res/body.png")
	state.textures.tail = rl.LoadTexture("res/tail.png")

	state.sounds.eat = rl.LoadSound("res/eat.wav")
	state.sounds.crash = rl.LoadSound("res/uhh.wav")

	gamepad_name := rl.GetGamepadName(0)
	if gamepad_name != "" {
		log.info("Gamepad connected: ", gamepad_name)
	}
}

process_input :: proc(state: ^GameState) {
	if (rl.IsGamepadAvailable(0)) {
		if rl.IsGamepadButtonDown(0, rl.GamepadButton.LEFT_FACE_UP) {
			state.snake.direction = {0, -1}
		}
		if rl.IsGamepadButtonDown(0, rl.GamepadButton.LEFT_FACE_DOWN) {
			state.snake.direction = {0, 1}
		}
		if rl.IsGamepadButtonDown(0, rl.GamepadButton.LEFT_FACE_LEFT) {
			state.snake.direction = {-1, 0}
		}
		if rl.IsGamepadButtonDown(0, rl.GamepadButton.LEFT_FACE_RIGHT) {
			state.snake.direction = {1, 0}
		}

		leftx := rl.GetGamepadAxisMovement(0, rl.GamepadAxis.LEFT_X)
		lefty := rl.GetGamepadAxisMovement(0, rl.GamepadAxis.LEFT_Y)
		if leftx < -GAMEPAD_LIMIT {
			state.snake.direction = {-1, 0}
		}
		if leftx > GAMEPAD_LIMIT {
			state.snake.direction = {1, 0}
		}
		if lefty < -GAMEPAD_LIMIT {
			state.snake.direction = {0, -1}
		}
		if lefty > GAMEPAD_LIMIT {
			state.snake.direction = {0, 1}

		}

		if rl.IsGamepadButtonPressed(0, rl.GamepadButton.MIDDLE_RIGHT) {
			state.keys.restart_down = true
		}
	}

	if rl.IsKeyDown(.UP) {
		state.snake.direction = {0, -1}
	}
	if rl.IsKeyDown(.DOWN) {
		state.snake.direction = {0, 1}
	}
	if rl.IsKeyDown(.LEFT) {
		state.snake.direction = {-1, 0}
	}
	if rl.IsKeyDown(.RIGHT) {
		state.snake.direction = {1, 0}
	}

	if rl.IsKeyPressed(.ENTER) {
		state.keys.restart_down = true
	}
}

eat :: proc(state: ^GameState) {
	rl.PlaySound(state.sounds.eat)
	rl.SetGamepadVibration(0, 1.0, 1.0, 500)
	place_food(state)
	state.camera_shake_duration = CAMERA_SHAKE_DURATION
}

prang :: proc(state: ^GameState) {
	rl.PlaySound(state.sounds.crash)
	rl.SetGamepadVibration(0, 1.0, 1.0, 500)
	state.camera_shake_duration = CAMERA_SHAKE_DURATION
	state.game_over = true
	state.high_score = state.score
}

update :: proc(state: ^GameState) {
	if state.game_over {
		if state.keys.restart_down {
			restart(state)
		}
	} else {
		state.tick_timer -= rl.GetFrameTime()
	}

	if state.tick_timer <= 0 {
		next_part_pos := state.snake.body[0]
		// If the snake has turned back on itself
		if state.snake.body[0] + state.snake.direction == state.snake.body[1] {
			state.snake.direction *= -1
		}
		state.snake.body[0] += state.snake.direction
		head_pos := state.snake.body[0]

		if head_pos.x >= GRID_WIDTH {
			state.snake.body[0].x %= GRID_WIDTH
		}
		if head_pos.x < 0 {
			state.snake.body[0].x = GRID_WIDTH + state.snake.body[0].x
		}
		if head_pos.y >= GRID_WIDTH {
			state.snake.body[0].y %= GRID_WIDTH
		}
		if head_pos.y < 0 {
			state.snake.body[0].y = GRID_WIDTH + state.snake.body[0].y
		}

		for i in 1 ..< state.snake.len {
			cur_pos := state.snake.body[i]

			if cur_pos == head_pos && i > 1 {
				prang(state)
			}

			state.snake.body[i] = next_part_pos
			next_part_pos = cur_pos
		}

		if head_pos == state.food_pos {
			state.snake.len += 1
			state.snake.body[state.snake.len - 1] = next_part_pos
			eat(state)
		}

		state.tick_timer += TICK_RATE
	}

	if state.camera_shake_duration > 0 {
		state.camera.offset.x = f32(
			rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE),
		)
		state.camera.offset.y = f32(
			rl.GetRandomValue(-CAMERA_SHAKE_MAGNITUDE, CAMERA_SHAKE_MAGNITUDE),
		)
		state.camera_shake_duration -= 1
	} else {
		state.camera.offset = {0, 0}
	}
}

render :: proc(state: ^GameState) {
	rl.DrawTextureV(
		state.textures.food,
		{f32(state.food_pos.x), f32(state.food_pos.y)} * CELL_SIZE,
		rl.WHITE,
	)

	for i in 0 ..< state.snake.len {
		part_sprite := state.textures.body
		dir: Vec2i

		if i == 0 {
			part_sprite = state.textures.head
			dir = state.snake.body[i] - state.snake.body[i + 1]
		} else if i == state.snake.len - 1 {
			part_sprite = state.textures.tail
			dir = state.snake.body[i - 1] - state.snake.body[i]
		} else {
			dir = state.snake.body[i - 1] - state.snake.body[i]
		}

		rot := math.atan2(f32(dir.y), f32(dir.x)) * math.DEG_PER_RAD

		src := rl.Rectangle{0, 0, f32(part_sprite.width / 2), f32(part_sprite.height)}
		dst := rl.Rectangle {
			f32(state.snake.body[i].x) * CELL_SIZE + 0.5 * CELL_SIZE,
			f32(state.snake.body[i].y) * CELL_SIZE + 0.5 * CELL_SIZE,
			CELL_SIZE,
			CELL_SIZE,
		}
		rl.DrawTexturePro(part_sprite, src, dst, {CELL_SIZE, CELL_SIZE} * 0.5, rot, rl.WHITE)
	}

	if state.game_over {
		rl.DrawText(
			state.ui.game_over.str,
			CANVAS_SIZE / 2 - state.ui.game_over.width / 2,
			CANVAS_SIZE / 2 - state.ui.game_over.size / 2,
			state.ui.game_over.size,
			LIGHT_PURPLEISH.rgba,
		)

		rl.DrawText(
			state.ui.new_game_ins.str,
			CANVAS_SIZE / 2 - state.ui.new_game_ins.width / 2,
			CANVAS_SIZE / 2 - state.ui.new_game_ins.size / 2 + state.ui.game_over.size,
			state.ui.new_game_ins.size,
			DARK_PURPLEISH.rgba,
		)
	}

	state.score = u8(state.snake.len - INIT_SNAKE_LEN)
	score_str := fmt.ctprintf("Score: %v [%v]", state.score, state.high_score)
	rl.DrawText(score_str, 4, 4, 8, rl.GRAY)
}

place_food :: proc(state: ^GameState) {
	occupied: [GRID_WIDTH][GRID_WIDTH]bool
	for i in 0 ..< state.snake.len {
		occupied[state.snake.body[i].x][state.snake.body[i].y] = true
	}

	free_cells := make([dynamic]Vec2i, context.temp_allocator)
	for x in i8(0) ..< GRID_WIDTH {
		for y in i8(0) ..< GRID_WIDTH {
			if !occupied[x][y] {
				append(&free_cells, Vec2i{x, y})
			}
		}
	}

	if len(free_cells) > 0 {
		random_cell_index := rl.GetRandomValue(0, i32(len(free_cells) - 1))
		state.food_pos = free_cells[random_cell_index]
	}
}

restart :: proc(state: ^GameState) {
	start_head_pos := Vec2i{GRID_WIDTH / 2, GRID_WIDTH / 2}
	state.snake.body[0] = start_head_pos
	state.snake.body[1] = start_head_pos - {0, 1}
	state.snake.body[2] = start_head_pos - {0, 2}
	state.snake.len = INIT_SNAKE_LEN
	state.snake.direction = {0, 1}

	state.game_over = false
	state.keys.restart_down = false
	if state.score > state.high_score {
		state.high_score = state.score
	}
	state.score = 0

	place_food(state)
}

stop :: proc(state: ^GameState) {
	rl.UnloadTexture(state.textures.head)
	rl.UnloadTexture(state.textures.food)
	rl.UnloadTexture(state.textures.body)
	rl.UnloadTexture(state.textures.tail)

	rl.UnloadSound(state.sounds.eat)
	rl.UnloadSound(state.sounds.crash)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}
