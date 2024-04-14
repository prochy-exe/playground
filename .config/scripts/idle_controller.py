import json, signal, subprocess, sys, time, os

idlehook_command = ["idlehook", "--not-when-fullscreen", "--timer", "300", "betterlockscreen -l dim", "", "--timer", "600", "systemctl suspend", ""]
dpms_command_idle = ["xset", "dpms", "1200", "1500", "1800"]
dpms_command_active = ["xset", "dpms", "0", "0", "0"]

def signal_handler(signal, frame):
    print("Exiting...")
    sys.exit(0)

def main():
    idlehook_process = None
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    audio_blacklist = ["PulseAudio Volume Control"]
    user_app_blacklist = ["virtualbox","virt-manager"]
    app_blacklist = []
    current_user = os.getenv("USER")
    app_running = False
    user_app_running = False
    caffeine = False

    while True:
        caffeine = True if open('/home/prochy/.config/scripts/caffeine_status', 'r').read() == "1" else False
        def audio_playing():
            json_data = json.loads(
                subprocess.check_output(["pw-dump"], universal_newlines=True)
            )
            parsed_data = {}
            final_data = {}
            for audio_interface in json_data:
                if (
                    audio_interface["type"] == "PipeWire:Interface:Node"
                    and "state" in audio_interface["info"]
                    and "stream.is-live" in audio_interface["info"]["props"]
                    and audio_interface["info"]["props"]["node.name"] != "cava"
                ):
                    parsed_data[audio_interface["id"]] = audio_interface

            for interface in parsed_data:
                if ".output" in parsed_data[interface]["info"]["props"]["node.name"]:
                    parent_name = parsed_data[interface]['info']['props']['node.name'].split(".output")[0]
                elif parsed_data[interface]["info"]["props"]["node.name"].lower() == parent_name.lower():
                    continue
                else:
                    final_data[interface] = parsed_data[interface]

            for final_interface in final_data:
                if ("input" in final_data[final_interface]["info"]["props"]["node.name"]
                    or final_data[final_interface]["info"]["props"]["node.name"] in audio_blacklist
                ):
                    #print(f"Skipping {final_data[final_interface]['info']['props']['node.name']}")
                    continue
                if final_data[final_interface]["info"]["state"] == "running":
                    #print(f"Audio detected on {final_data[final_interface]['info']['props']['node.name']}")
                    return True
            return False

        for user_app in user_app_blacklist:
            output = subprocess.run(["pgrep", "-u", f"{current_user}", "-f", f"{user_app}"], stdout=subprocess.PIPE).stdout.decode("utf-8")
            if output:
                user_app_running = True
                break
            else:
                user_app_running = False

        for app in app_blacklist:
            output = subprocess.run(["pgrep", "-f", f"{app}"], stdout=subprocess.PIPE).stdout.decode("utf-8")
            if output:
                app_running = True
                break
            else:
                app_running = False

        try:
            is_audio_playing = audio_playing()
        except:
            is_audio_playing = False

        #Main logic
        try:
            if is_audio_playing or (app_running or user_app_running) or caffeine:
                if idlehook_process:
                    print("Killing idlehook")
                    idlehook_process.terminate()
                    idlehook_process = None
                    subprocess.Popen(
                        dpms_command_active
                    )
                open("/home/prochy/.config/scripts/idle_status", "w").write("0")
            else:
                if not idlehook_process:
                    print("Starting idlehook")
                    idlehook_process = subprocess.Popen(
                        idlehook_command,
                        stdout=subprocess.PIPE,
                    )
                    subprocess.Popen(
                        dpms_command_idle
                    )
                open("/home/prochy/.config/scripts/idle_status", "w").write("1")
            time.sleep(5)

        except KeyboardInterrupt:
            if idlehook_process:
                idlehook_process.terminate()
            sys.exit(0)

        except Exception:
            continue

if __name__ == "__main__":
    main()