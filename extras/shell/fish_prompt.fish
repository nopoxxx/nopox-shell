# nopox-shell: приглашение как панель nopox — user@host ~/путь ❯ (красный ❯, если команда завершилась ошибкой)
function fish_prompt
    set -l st $status
    set_color --bold green; echo -n $USER; set_color normal
    set_color brblack; echo -n @
    set_color --bold cyan; echo -n (prompt_hostname); set_color normal
    echo -n ' '
    set_color blue; echo -n (prompt_pwd); set_color normal
    if test $st -eq 0
        set_color yellow
    else
        set_color red
    end
    echo -n ' ❯ '
    set_color normal
end
