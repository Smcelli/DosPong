STACK segment para STACK
    db 64 dup (' ')
STACK ends

DATA segment para 'DATA'
    
    window_width dw 320d                    ;320 pixels
    window_height dw 200d                   ;200 pixels
    window_bounds dw 6d                     ;6 pixel boundry 
    
    time_last db 0                           ;variable to store time of last frame
    game_stage db 1                         ;0(game_over) 1(active play)

    ball_origin_x dw 0A0h                   ;160 pixels
    ball_origin_y dw 64h                    ;100 pixels
    ball_x dw 1Ah                           ;ball x position
    ball_y dw 1Ah                           ;ball y position
    ball_size dw 04h                        ;size of ball width and height
    
    paddle_y_origin dw 80d
    paddle_left_x dw 0Ah
    paddle_left_y dw 80d
    paddle_right_x dw 12ch
    paddle_right_y dw 80d
    paddle_width dw 0Ah
    paddle_height dw 28h
    paddle_velocity_base dw 04h
    paddle_velocity_left dw 00h
    paddle_velocity_right dw 00h
    
    ball_velocity_x dw 05h                  ;horizontal velocity
    ball_velocity_y dw 02h                  ;vertical velocity
    
    color_black dw 00h
    color_white dw 0Fh
    
    points_left dw 0
    points_right dw 0
    points_max dw 1d
    
    text_points_left db '0','$'
    text_points_right db '0','$'
    text_game_over db 'GAME OVER','$'
    text_right_wins db 'RIGHT WINS','$'
    text_left_wins db 'LEFT WINS','$'
    

DATA ends

CODE segment para 'CODE'

main proc far
assume cs:CODE,ds:DATA,ss:STACK             ;define code, data, and stack segments
push ds                                     ;push ds to stack
xor ax,ax                                   ;clear ax register
mov ax, DATA
mov ds, ax

push es                                     ;save contents of es and move the video buffer address into it
mov ax, 0A000h              
mov es, ax
cld             

    call set_screen
    
    check_time:
    
        mov ah, game_stage
        test ah,ah
        jz game_stage_game_over             ;check if gameloop should move to game over menu
        
        mov ah,2ch                          ;get system time ch = hour cl = minute dh = second dl = 1/100 seconds
        int 21h                             ;dos interupt
        
        cmp dl,time_last                    ;is current time equal to previous
        je check_time                       ;game loop updates maximum every 1/100 seconds
        mov time_last,dl                    ;update previous loop time
        
        call clear_screen                   ;game loop
        call draw_ui
        call read_paddle_input
        call move_paddles
        call draw_paddles
        call move_ball
        jmp check_time
        
    game_stage_game_over:                   ;game over menu
    call draw_game_over_menu
    jmp check_time                          ;requires method to exit game
    
    main_end:
    pop es
    pop ds
    ret
main endp

;set_screen() => null
;sets the value of the screen to 13h (320x200) with a black background
;no arguments
;returns nothing
set_screen proc near
    
    mov ah,00h                              ;set video mode
    mov al,13h                              ;graphics 320x200x8bit
    int 10h             
    
    mov ah, 0bh                             ;set background color
    mov bh, 00h         
    mov bl, 00h
    int 10h
    
    ret
set_screen endp

;clear_screen() => null
;sets all screen pixels to black
;no arguments
;returns nothing
clear_screen proc near
    
    xor di,di                               ;es holds the video buffer address
    mov cx, 64000                           ;stosb is used to set 64000 (320x200) pixels to black
    mov al, 0
    rep stosb
    
    ret
clear_screen endp

;read_paddle_input() => null
;determines which paddles is allowed to move and reads wsol keys to set paddle velocity
;no arguments
;returns nothing
;((should re-write to not use in 16h to allow simultaneous movement and more responsive controls, needs to read directly from keyboard input))
read_paddle_input proc near
    push bp
    mov bp, sp
    xor ax, ax
    xor dx, dx
    
    mov ah, 01h
    int 16h
    jz stop_paddles
    
    xor ax, ax          
    int 16h                                 ;al now holds ascii character being pressed
    mov dx, ball_velocity_x
    test dx, dx
    js check_left_paddle
    
    cmp al, 6Fh                             ;compare key to 'o'
    je move_right_paddle_up
    
    cmp al, 6Ch                             ;compare key to 'l'    
    je move_right_paddle_down
    jmp stop_paddles
    
    check_left_paddle:
    cmp al, 77h                             ;compare key to 'w'
    je move_left_paddle_up
    
    cmp al, 73h                             ;compare key to 's'
    je move_left_paddle_down
    jmp stop_paddles

    move_right_paddle_up:
    mov ax, paddle_velocity_base
    neg ax
    mov paddle_velocity_right, ax
    xor ax, ax
    mov paddle_velocity_left, ax
    jmp read_paddle_input_end
    
    move_right_paddle_down:
    mov ax, paddle_velocity_base
    mov paddle_velocity_right, ax
    xor ax, ax
    mov paddle_velocity_left, ax
    jmp read_paddle_input_end
    
    move_left_paddle_up:
    mov ax, paddle_velocity_base
    neg ax
    mov paddle_velocity_left, ax
    xor ax, ax
    mov paddle_velocity_right, ax
    jmp read_paddle_input_end
    
    move_left_paddle_down:
    mov ax, paddle_velocity_base
    mov paddle_velocity_left, ax
    xor ax, ax
    mov paddle_velocity_right, ax
    jmp read_paddle_input_end
    
    stop_paddles:
    xor ax,ax
    mov paddle_velocity_left, ax
    mov paddle_velocity_right, ax
    
    read_paddle_input_end:
    mov sp, bp
    pop bp
    ret
read_paddle_input endp

;move_paddles() => null
;uses paddle velocity to alter y coordinate of paddles inbetween draws, checks collision between paddles and screen borders
;no arguments
;returns nothing
move_paddles proc near
    push bp
    mov bp, sp
    xor ax, ax
    xor dx, dx
    
    mov dx, window_height
    sub dx, window_bounds
    sub dx, paddle_height
    
    mov ax, paddle_left_y
    add ax, paddle_velocity_left
    
    cmp ax, dx
    jg move_right_paddle
    cmp ax, window_bounds
    jl move_right_paddle
    mov paddle_left_y, ax
    
    move_right_paddle:
    mov ax, paddle_right_y 
    add ax, paddle_velocity_right
    cmp ax, dx
    jg move_paddles_end
    cmp ax, window_bounds
    jl move_paddles_end
    mov paddle_right_y, ax
    
    move_paddles_end:
    mov sp, bp
    pop bp
    ret
move_paddles endp

;move_ball() => null
;uses ball velocities to change ball's (x,y). checks collisions between the ball and paddles/borders/score zones and responds if detected.  Calls function to draw the ball
;no arguments 
;returns nothing
;((function is bloated and has exceeded original intention, todo split into pieces))
move_ball proc near
    push bp
    mov bp, sp
    xor ax, ax
    xor dx, dx
    
    mov ax,ball_velocity_x
    add ball_x,ax
    
    mov ax, window_bounds
    cmp ball_x, ax                          ;check left bound
    jng score                               ;skip other bound check if ball is in bounds
    
    mov ax, window_width                    ;check right bound window width - window bound - ball size
    sub ax, window_bounds                   ;use ball right bound instead of leftmost coord
    sub ax, ball_size
    cmp ball_x, ax
    jl check_paddle_collisions              ;skip score if ball is in bounds
    
    score:
    neg ball_velocity_x                     ;ball_velocity_x * -1
    js point_player_left                    ;if (ball_velocity_x is !negative)
    inc points_right                        ;player_left_points++
    inc text_points_right
    jmp reset_game_state                    ;else
    point_player_left:                      ;player_right_points++
    inc points_left
    inc text_points_left
    reset_game_state:
    call reset_positions
    jmp move_ball_y_end
        
    check_paddle_collisions:
    ;check_collision(rect1_x, rect1_y, rect1_width, rect1_height, rect2_x, rect2_y, rect2_width, rect2_height) => ax: 0|!0
    push ball_size
    push ball_size
    push ball_y
    push ball_x
    push paddle_height
    push paddle_width
    push paddle_left_y
    push paddle_left_x
    call check_collision
    jnz paddle_collision                    ;if check_collision ret !0 skip to paddle_collision
    
    add sp, 4                               ;pop paddle_left_x and paddle_left_y
    push paddle_right_y                     ;push paddle_right_x and paddle_right_y
    push paddle_right_x
    call check_collision
    jz paddle_collision_end                 ;if check_collision ret 0 skip paddle collision

    paddle_collision:
    add sp, 16
    neg ball_velocity_x
    mov ax, ball_x
    add ax, ball_velocity_x
    mov ball_x, ax
    paddle_collision_end:
    
    mov ax,ball_velocity_y
    add ball_y,ax
    
    mov ax, window_bounds
    cmp ball_y, ax                          ;repeat above procedure for top and bottom
    jng neg_y_velocity
    
    mov ax, window_height
    sub ax, window_bounds
    sub ax, ball_size
    cmp ball_y, ax
    jl move_ball_y_end

    neg_y_velocity:
    neg ball_velocity_y
    move_ball_y_end:
    
    ;draw_ball(color) => null
    push color_white
    call draw_ball              
    add sp,2
    
    mov sp, bp
    pop bp
    ret
move_ball endp

;check_collision(rect1_x, rect1_y, rect1_width, rect1_height, rect2_x, rect2_y, rect2_width, rect2_height) => ax: 0|!0
;checks for a collision between 2 aligned rectangles
;8 arguments on stack 
;(rect1_x, rect1_y, rect1_width, rect1_height, rect2_x, rect2_y, rect2_width, rect2_height)
;returns in ax 0 if no collision, and a non-zero value if there is
check_collision proc near
    push bp
    mov bp, sp
    xor ax, ax
    xor dx, dx
    
    ; rect1_x [bp+4]
    ; rect1_y [bp+6]
    ; rect1_width [bp+8]
    ; rect1_height [bp+10]
    ; rect2_x [bp+12]
    ; rect2_y [bp+14]
    ; rect2_width [bp+16]
    ; rect2_height [bp+18]
    
    mov ax, [bp+4]                          ;if( rect1_x < rect2_x + rect2_width    
    mov dx, [bp+12]
    add dx, [bp+16]
    cmp ax, dx
    jnl collision_zero        
    add ax, [bp+8]                          ; && rect1_x + rect1_width > rect2_x
    mov dx, [bp+12]
    cmp ax, dx
    jng collision_zero
    mov ax, [bp+6]                          ; && rect1_y < rect2_y + rect2_height    
    mov dx, [bp+14]
    add dx, [bp+18]
    cmp ax, dx
    jnl collision_zero
    add ax, [bp+10]                         ; && rect1_y + rect1_height > rect2_y
    mov dx, [bp+14]
    cmp ax, dx
    jng collision_zero
    jmp check_collision_end                 ;) then collision
    
    collision_zero:
    xor ax,ax
    check_collision_end:
    mov sp, bp
    pop bp
    ret
check_collision endp

;draw_ui() => null
;prints to screen the scores of right and left players
;no arguments
;returns nothing
;((rename? name is not a clear indicator of function))
draw_ui proc near
    push bp
    mov bp, sp
    push bx
    xor ax,ax
    xor dx,dx
    
    ;draw left points:
    ;print_string_to_screen(string address, row, column) => null
    mov ax, 06h                             ;column    
    push ax
    mov ax, 04h                             ;row
    push ax
    lea ax, text_points_left                ;string address
    push ax
    call print_string_to_screen
    add sp, 6
    
    ;draw right points:
    ;print_string_to_screen(string address, row, column) => null
    mov ax, 20h                             ;column
    push ax
    mov ax, 04h                             ;row
    push ax
    lea ax, text_points_right               ;string address
    push ax
    call print_string_to_screen
    add sp, 6
    
    pop bx
    mov sp,bp
    pop bp
    ret
draw_ui endp 

;draw_game_over_menu() => null
;clears screen and displays game over text as well as text indicating the winner
;no arguments
;returns nothing
draw_game_over_menu proc near
    push bp
    mov bp, sp
    xor ax,ax
    
    call clear_screen
    
    ;print game over menu title:
    ;print_string_to_screen(string address, row, column) => null
    mov ax, 10h                             ;column
    push ax
    mov ax, 04h                             ;row
    push ax
    lea ax, text_game_over                  ;string address
    push ax
    call print_string_to_screen
    add sp, 6
    
    ;print winner:
    ;print_string_to_screen(string address, row, column) => null
    mov ax, 10h                             ;column           
    push ax
    mov ax, 05h                             ;row
    push ax
    
    mov ax, points_left                     ;if (points left > points right) print text_left_wins
    cmp ax, points_right 
    jl right_wins
    lea ax, text_left_wins
    push ax
    jmp left_wins
    right_wins:                             ;else print text_right_wins
    lea ax, text_right_wins                 ;string address
    push ax
    left_wins:
    call print_string_to_screen
    add sp, 6
    
    mov al, 1                               ;reset game state to 1 and all points to 0
    mov game_stage, al
    xor ax,ax
    mov points_left, ax
    mov points_right,ax
    mov al, '0'
    mov [text_points_left], al
    mov [text_points_right], al
    
    mov ah, 00h                             ;wait for keypress
    int 16h
    
    mov sp,bp
    pop bp
    ret
draw_game_over_menu endp

;print_string_to_screen(string address, row, column) => null
;prints string at address given to screen at row, column given
;uses ax, dx registers
;all arguments should be pushed onto stack
;returns nothing
print_string_to_screen proc near
    push bp
    mov bp, sp
    xor ax,ax
    xor dx,dx
    push bx
    
    ;[bp+6]row
    ;[bp+8]column
    ;[bp+4]address of text
    
    mov ah, 02h                             ;int 10h cursor position 
    mov bh, 00h                             ;page #
    mov dh, [bp+6]                          ;set row
    mov dl, [bp+8]                          ;set column
    int 10h
    
    mov ah, 09h                             ;write to std out
    mov dx, [bp+4]                          ;load address of text    
    int 21h                                 ;write to screen
    
    pop bx
    mov sp,bp
    pop bp
    ret
print_string_to_screen endp

;draw_ball(color) => null
;draws a rectangle using variables ball_x, ball_y, and ball_size
;argument (color) should be pushed onto the stack
;returns nothing
draw_ball proc near     
    push bp
    mov bp,sp
    
    ;draw_rectangle(color, x, y, width , height) => null
    mov ax, ball_size                       ;height
    push ax
    mov ax, ball_size                       ;width
    push ax
    push ball_y                             ;y
    push ball_x                             ;x
    push [bp+4]                             ;color
    call draw_rectangle
    add sp, 10
    
    mov sp, bp
    pop bp
    ret
draw_ball endp

;draw_paddles(color)
;draws paddles to screen
;uses variables paddle_left_x, paddle_left_y, paddle_right_x, paddle_right_y, 
;paddle_width, paddle_height, and color_white
;argument (color) should be pushed onto the stack
;returns nothing
draw_paddles proc near
    push bp
    mov bp,sp
    push ax
    
    ;left paddle:
    ;draw_rectangle(color, x, y, width , height) => null
    mov ax, paddle_height                   ;height
    push ax
    mov ax, paddle_width                    ;width
    push ax
    push paddle_left_y                      ;y
    push paddle_left_x                      ;x
    push color_white                        ;color
    call draw_rectangle
    add sp, 10
    
    ;right paddle:
    ;draw_rectangle(color, x, y, width , height) => null
    mov ax, paddle_height                   ;height
    push ax
    mov ax, paddle_width                    ;width
    push ax
    push paddle_right_y                     ;y
    push paddle_right_x                     ;x
    push color_white                        ;color
    call draw_rectangle
    add sp, 10
    
    pop ax
    mov sp,bp
    pop bp
    ret
draw_paddles endp

;draw_rectangle(color, x, y, width , height) => null
;uses passed arguments to draw a rectangle to the screen of size width x height
;arguments (color, x, y, width , height) should be pushed onto the stack
;returns nothing
draw_rectangle proc near
    push bp
    mov bp, sp
    push bx
    
    ; color [bp+4]
    ; x [bp+6]
    ; y [bp+8]
    ; width [bp+10]
    ; height [bp+12]
    
    draw_line:
        mov ax, [bp+8]
        mov dx, 320
        mul dx
        mov bx, [bp+6]
        add ax, bx
        mov di, ax                          ;di = (320 x y) + x
        mov cx, [bp+10]
        mov ax, [bp+4]
        rep stosb                           ;colors pixels white starting at point in di and continueing for width pixels
        
        mov dx, [bp+12]
        dec dx                              ;decrement height and draw another line or end function if height is 0
        jz draw_rectangle_end
        mov [bp+12], dx
        mov ax, [bp+8]
        inc ax
        mov [bp+8],ax
        jmp draw_line
    
    draw_rectangle_end:
    pop bx
    mov sp, bp
    pop bp
    ret
draw_rectangle endp

;draw_rectangle_int
;not in use, in attempt to reduce flickering
;uses int 10h to draw a rectangle to the screen of size width x height at coordinates x,y
;arguments (color, x, y, x + width , y + height) should be pushed onto the stack
;returns nothing
draw_rectangle_int proc near
    push bp
    mov bp, sp
    push bx
    
    ; color [bp+4]
    ; x [bp+6]
    ; y [bp+8]
    ; x+width [bp+10]
    ; y+height [bp+12]
    
    mov cx, [bp+6]                          ;set initial x
    mov dx, [bp+8]                          ;set initial y
    
    draw_rectangle_loop:
        mov ah, 0ch                         ;write pixel
        mov al, [bp+4]                      ;set color        
        mov bh, 00h                         ;page    
        int 10h                 
        
        inc cx                              ;inc x coord
        mov ax, [bp+10]
        cmp cx, ax                          ;if (current_x < x+width) loop
        jl draw_rectangle_loop
        
        mov cx, [bp+6]                      ;reset to inital x
        inc dx                              ;inc y coord
        mov ax, [bp+12]
        cmp dx, ax                          ;if (current_y < y+width) loop
        jl draw_rectangle_loop

    pop bx
    mov sp, bp
    pop bp
    ret
draw_rectangle_int endp

;reset_positions() => null
;sets current position of paddles and ball to origin points and checks if either player has reached max points
;no arguments
;returns nothing
reset_positions proc near
    mov ax, ball_origin_x
    mov ball_x, ax
    mov ax, ball_origin_y
    mov ball_y, ax
    
    mov ax, paddle_y_origin
    mov paddle_left_y, ax
    mov paddle_right_y, ax
    
    ;if a player has reached points_max
    mov ax, points_max
    cmp ax, points_left                     ;if (max < points) game_over
    jl game_over
    cmp ax, points_right                    ;if (!(max < points)) skip game_over
    jnl reset_positions_end             
    
    game_over:
    mov al, 0
    mov game_stage, al
    
    reset_positions_end:
    ret
reset_positions endp

CODE ends
end