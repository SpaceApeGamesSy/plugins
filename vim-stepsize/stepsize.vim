function! s:get_visual_selection()
  let [lnum1, col1] = getpos("v")[1:2]
  let [lnum2, col2] = getpos(".")[1:2]
  let lines = getline(lnum1, lnum2)
  return join(lines, "\n")
endfunction

function! PyStepsizeEvent(action)
    let l:filename = expand("%:p")
    let currentmode = mode()
    if currentmode =~? '.*v'
      let l:selected = s:get_visual_selection()
    else
      let l:selected = getline('.')
    endif
python << endpython
import vim
import os
import json
import socket

pluginId = 'vim_v0.0.1'

def cursor_pos(buf, pos):
    (line, col) = pos
    return sum(len(l) for l in buf[:line-1]) + col + (line-1)

def realpath(p):
    try:
        return os.path.realpath(p)
    except:
        return p

def send_event(action, filename):
    pos = cursor_pos(list(vim.current.buffer),
                    vim.current.window.cursor)

    text = '\n'.join(vim.current.buffer)
    selections = [{'start': pos, 'end': pos}]
    selected = vim.eval("l:selected")
    if selected == '0':
      selected = ''

    event = {
        'source': 'vim',
        'action': action,
        'filename': realpath(filename),
        'selected': selected,
        'selections': [{'start': pos, 'end': pos}],
        'plugin_id': pluginId
    }

    if len(event['selected']) > (1 << 20): # 1mb
        event['action'] = 'skip'
        event['selected'] = 'file_too_large'

    SOCK_ADDRESS = ('localhost', 49369)
    SOCK_BUF_SIZE = 2 << 20
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, SOCK_BUF_SIZE)
    sock.sendto(json.dumps(event), SOCK_ADDRESS)


send_event(vim.eval("a:action"), vim.eval("l:filename"))
endpython
endfunction


if has('python')
    augroup StepsizePlugin
        autocmd CursorMoved  * :call PyStepsizeEvent('selection')
        autocmd CursorMovedI * :call PyStepsizeEvent('edit')
        autocmd BufEnter     * :call PyStepsizeEvent('focus')
        autocmd BufLeave     * :call PyStepsizeEvent('lost_focus')
    augroup END
endif
