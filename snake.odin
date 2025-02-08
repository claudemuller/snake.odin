package snake

import "core:fmt"
import "core:log"
import "core:math"
import rl "vendor:raylib"

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE
TICK_RATE :: 0.13
MAX_SNAKE_LEN :: GRID_WIDTH * GRID_WIDTH
INIT_SNAKE_LEN :: 3
PURPLEISH :: [4]u8{76, 53, 83, 255}

snake_len: int
snake: [MAX_SNAKE_LEN]Vec2i
food_pos: Vec2i
move_direction: Vec2i

tick_timer: f32 = TICK_RATE

Vec2i :: [2]int

UI :: struct {
	str:   cstring,
	size:  i32,
	width: i32,
}

GameState :: struct {
	sounds:    struct {
		eat:   rl.Sound,
		crash: rl.Sound,
	},
	textures:  struct {
		head: rl.Texture,
		body: rl.Texture,
		tail: rl.Texture,
		food: rl.Texture,
	},
	ui:        struct {
		game_over:    UI,
		new_game_ins: UI,
	},
	game_over: bool,
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
		process_input()

		update(&state)

		rl.BeginDrawing()
		rl.ClearBackground(PURPLEISH.rgba)

		camera := rl.Camera2D {
			zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,
		}
		rl.BeginMode2D(camera)

		render(&state)

		rl.EndMode2D()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	stop(&state)
}

init :: proc(state: ^GameState) {
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
	state.sounds.crash = rl.LoadSound("res/crash.wav")
}

process_input :: proc() {
	if rl.IsKeyDown(.UP) {
		move_direction = {0, -1}
	}
	if rl.IsKeyDown(.DOWN) {
		move_direction = {0, 1}
	}
	if rl.IsKeyDown(.LEFT) {
		move_direction = {-1, 0}
	}
	if rl.IsKeyDown(.RIGHT) {
		move_direction = {1, 0}
	}
}

update :: proc(state: ^GameState) {
	if state.game_over {
		if rl.IsKeyPressed(.ENTER) {
			restart(state)
		}
	} else {
		tick_timer -= rl.GetFrameTime()
	}

	if tick_timer <= 0 {
		next_part_pos := snake[0]
		snake[0] += move_direction
		head_pos := snake[0]

		if head_pos.x < 0 ||
		   head_pos.x >= GRID_WIDTH ||
		   head_pos.y < 0 ||
		   head_pos.y >= GRID_WIDTH {
			state.game_over = true
			rl.PlaySound(state.sounds.crash)
		}

		for i in 1 ..< snake_len {
			cur_pos := snake[i]

			if cur_pos == head_pos {
				state.game_over = true
				rl.PlaySound(state.sounds.crash)
			}

			snake[i] = next_part_pos
			next_part_pos = cur_pos
		}

		if head_pos == food_pos {
			snake_len += 1
			snake[snake_len - 1] = next_part_pos
			place_food()
			rl.PlaySound(state.sounds.eat)
		}

		tick_timer += TICK_RATE
	}

}

render :: proc(state: ^GameState) {
	rl.DrawTextureV(state.textures.food, {f32(food_pos.x), f32(food_pos.y)} * CELL_SIZE, rl.WHITE)

	for i in 0 ..< snake_len {
		part_sprite := state.textures.body
		dir: Vec2i

		if i == 0 {
			part_sprite = state.textures.head
			dir = snake[i] - snake[i + 1]
		} else if i == snake_len - 1 {
			part_sprite = state.textures.tail
			dir = snake[i - 1] - snake[i]
		} else {
			dir = snake[i - 1] - snake[i]
		}

		rot := math.atan2(f32(dir.y), f32(dir.x)) * math.DEG_PER_RAD

		src := rl.Rectangle{0, 0, f32(part_sprite.width), f32(part_sprite.height)}
		dst := rl.Rectangle {
			f32(snake[i].x) * CELL_SIZE + 0.5 * CELL_SIZE,
			f32(snake[i].y) * CELL_SIZE + 0.5 * CELL_SIZE,
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
			rl.RED,
		)

		rl.DrawText(
			state.ui.new_game_ins.str,
			CANVAS_SIZE / 2 - state.ui.new_game_ins.width / 2,
			CANVAS_SIZE / 2 - state.ui.new_game_ins.size / 2 + state.ui.game_over.size,
			state.ui.new_game_ins.size,
			rl.BLACK,
		)
	}

	score := snake_len - INIT_SNAKE_LEN
	score_str := fmt.ctprintf("Score: %v", score)
	rl.DrawText(score_str, 4, 4, 8, rl.GRAY)
}

place_food :: proc() {
	occupied: [GRID_WIDTH][GRID_WIDTH]bool
	for i in 0 ..< snake_len {
		occupied[snake[i].x][snake[i].y] = true
	}

	free_cells := make([dynamic]Vec2i, context.temp_allocator)
	for x in 0 ..< GRID_WIDTH {
		for y in 0 ..< GRID_WIDTH {
			if !occupied[x][y] {
				append(&free_cells, Vec2i{x, y})
			}
		}
	}

	if len(free_cells) > 0 {
		random_cell_index := rl.GetRandomValue(0, i32(len(free_cells) - 1))
		food_pos = free_cells[random_cell_index]
	}
}

restart :: proc(state: ^GameState) {
	start_head_pos := Vec2i{GRID_WIDTH / 2, GRID_WIDTH / 2}
	snake[0] = start_head_pos
	snake[1] = start_head_pos - {0, 1}
	snake[2] = start_head_pos - {0, 2}
	snake_len = INIT_SNAKE_LEN
	move_direction = {0, 1}
	state.game_over = false
	place_food()
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
