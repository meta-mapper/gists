<?php

// Set credentials to prevent public access
define('USERNAME', 'manjeet');
define('PASSWORD', 'knockknock');

// Set list of files which should be exluded from list
define('EXCLUDE_LIST', ['./index.php', 'README.md']);

// No changes needed below

// Authenticate before accessing the page
authenicate();

// Functions
function authenicate()
{
    //
    if (
        isset($_SERVER['PHP_AUTH_USER']) === false
        || isset($_SERVER['PHP_AUTH_PW']) === false
        ||  $_SERVER['PHP_AUTH_USER'] !== USERNAME
        || $_SERVER['PHP_AUTH_PW'] !== PASSWORD
    ) {

        header('WWW-Authenticate: Basic realm="Password Needed');
        header('HTTP/1.0 401 Unauthorized');

        exit('Authenication needed');
    }
}

function print_directory_tree($tree)
{
    //
    // $html = '<div>';
    $html = '';

    foreach ($tree['directories'] as $directory) {
        // 
        $html .= '<div class="item directory">
            <div class="self" onclick="toggleDirectory(this)">
                <div class="icon">
                    ' . print_folder_svg() . '
                </div>
                <div class="info">
                    <p class="name">' . $directory['name'] . '</p>
                    <p class="size">' . $directory['items_count'] . ' items</p>
                </div>
            </div>
            <div class="childs collapsed">
        ';

        if ($directory['items_count'] > 0) {
            // 
            $html .= print_directory_tree($directory['childs']);
        }

        $html .= '</div></div>';
    }

    foreach ($tree['files'] as $file) {
        // 
        $html .= '<div class="item file">
            <div class="self">
                <div class="icon">
                ' . print_file_svg() . '
                </div>
                <div class="info">
                    <p class="name">
                        <a href="' . $file['uri'] . '">' . $file['name'] . '</a>
                    </p>
                    <p class="size">' . $file['size'] . '</p>
                </div>
            </div>
        </div>';
    }

    // $html .= '</div>';

    return $html;
}

function get_directory_tree($directory)
{
    // 
    $tree = [
        'directories' => [],
        'files' => []
    ];

    $directory = rtrim($directory, DIRECTORY_SEPARATOR);

    $childs = scandir($directory);

    foreach ($childs as $child) {
        // 
        $child_path = $directory . DIRECTORY_SEPARATOR . $child;

        if (in_array($child, ['.', '..']) || in_array($child_path, EXCLUDE_LIST)) {
            //    
            continue;
        }

        if (is_dir($child_path)) {
            // 
            $directory_childs = get_directory_tree($child_path);

            $tree['directories'][] = [
                // 
                'name' => $child,
                'childs' => $directory_childs,
                'items_count' => count($directory_childs['directories']) + count($directory_childs['files'])
            ];

            continue;
        }

        $tree['files'][] = [
            'name' => $child,
            'size' => format_file_size(filesize($child_path)),
            'type' => pathinfo($child, PATHINFO_EXTENSION),
            'uri' => $child_path
        ];
    }
    return $tree;
}

function format_file_size($size)
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];

    $i = 0;

    while ($size > 1024) {
        // 
        $size /= 1024;

        $i++;
    }

    return round($size, 2) . ' ' . $units[$i];
}


function print_folder_svg()
{
    //
    return '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4 2C3.20435 2 2.44129 2.31607 1.87868 2.87868C1.31607 3.44129 1 4.20435 1 5V19C1 19.7957 1.31607 20.5587 1.87868 21.1213C2.44129 21.6839 3.20435 22 4 22H20C20.7957 22 21.5587 21.6839 22.1213 21.1213C22.6839 20.5587 23 19.7957 23 19V8C23 7.20435 22.6839 6.44129 22.1213 5.87868C21.5587 5.31607 20.7957 5 20 5H11.5352L10.1289 2.8906C9.75799 2.3342 9.13352 2 8.46482 2H4Z" fill="#000000"/></svg>';
}

function print_file_svg()
{
    //
    return '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g><path d="M12 12V18M12 18L15 16M12 18L9 16M13 3.00087C12.9045 3 12.7973 3 12.6747 3H8.2002C7.08009 3 6.51962 3 6.0918 3.21799C5.71547 3.40973 5.40973 3.71547 5.21799 4.0918C5 4.51962 5 5.08009 5 6.2002V17.8002C5 18.9203 5 19.4801 5.21799 19.9079C5.40973 20.2842 5.71547 20.5905 6.0918 20.7822C6.5192 21 7.07899 21 8.19691 21H15.8031C16.921 21 17.48 21 17.9074 20.7822C18.2837 20.5905 18.5905 20.2842 18.7822 19.9079C19 19.4805 19 18.9215 19 17.8036V9.32568C19 9.20296 19 9.09561 18.9991 9M13 3.00087C13.2856 3.00347 13.4663 3.01385 13.6388 3.05526C13.8429 3.10425 14.0379 3.18526 14.2168 3.29492C14.4186 3.41857 14.5918 3.59182 14.9375 3.9375L18.063 7.06298C18.4089 7.40889 18.5809 7.58136 18.7046 7.78319C18.8142 7.96214 18.8953 8.15726 18.9443 8.36133C18.9857 8.53376 18.9963 8.71451 18.9991 9M13 3.00087V5.8C13 6.9201 13 7.47977 13.218 7.90759C13.4097 8.28392 13.7155 8.59048 14.0918 8.78223C14.5192 9 15.079 9 16.1969 9H18.9991M18.9991 9H19.0002" stroke="#000000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></g></svg>';
}

function send_json($data)
{
    //
    header('Content-Type: application/json');
    return print_r(json_encode($data));
    exit;
}

?>



<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>qBittorrent Downloads</title>

    <style>
        :root {
            --primary-color: #3f3f3f;
            --border-color: #e5e5e5;
            --icon-size: 60rem;

            font-size: 1px;
        }

        * {
            box-sizing: border-box;
        }

        body,
        p {
            margin: 0;
            padding: 0;
        }

        body {
            font-family: sans-serif;
            font-size: 16rem;
        }

        .item.directory {
            cursor: pointer;
        }

        .self {
            border-bottom: 1rem solid var(--border-color);

            padding: 10rem 20rem;

            display: flex;
            align-items: center;

        }


        .icon {
            width: var(--icon-size);
            height: var(--icon-size);
            flex-shrink: 0;
        }

        .directory>.self>.icon svg path {
            fill: var(--primary-color);
        }

        .info {
            flex-grow: 1;
            margin-left: 15rem;
        }

        .name {
            color: var(--primary-color);
            font-size: 18rem;
            font-weight: bold;
            word-break: break-all;
        }

        .size {
            margin-top: 3rem;

            color: #666;
            font-size: 14rem;
        }

        .file>.self>.icon svg path {
            stroke: var(--primary-color);
        }

        .name>a {
            color: var(--primary-color);
            text-decoration: none;
        }

        .childs {
            border-left: 1rem solid var(--border-color);
            height: 0;

            margin-left: 40rem;
            padding: 0 20rem;

            overflow: hidden;
        }

        @media screen and (max-width: 768px) {
            :root {
                --icon-size: 50rem;
            }

            .self {
                padding: 10rem 15rem;
            }

            .childs {
                margin-left: 30rem;
                padding: 0 15rem;
            }

        }

        @media screen and (max-width: 480px) {
            :root {
                --icon-size: 40rem;
            }

            .self {
                padding: 5rem 10rem;
            }

            .name {
                font-size: 16rem;
            }

            .size {
                font-size: 12rem;
            }

            .childs {
                margin-left: 20rem;
                padding: 0 10rem;
            }

        }

        @media screen and (max-width: 320px) {
            :root {
                --icon-size: 30rem;
            }

            .self {
                padding: 5rem 5rem;
            }

            .name {
                font-size: 14rem;
            }

            .size {
                font-size: 10rem;
            }

            .childs {
                margin-left: 10rem;
                padding: 0 5rem;
            }
        }
    </style>

    <script>
        const init = () => {

        }

        const toggleDirectory = (element) => {
            //
            const childsElement = element.nextElementSibling;
            const heights = [0, childsElement.scrollHeight + 'rem']

            childsElement.animate({
                height: childsElement.clientHeight === 0 ? heights : heights.reverse()
            }, {
                duration: 300,
                easing: 'ease-in-out',
                fill: 'forwards'
            });
        }
    </script>

</head>

<body onload="init()">
    <div id="viewport">
        <?= print_directory_tree(get_directory_tree('./')) ?>
    </div>
</body>

</html>