FROM ros:jazzy
RUN apt -y -qq update && \
    apt -y -qq install \
    parallel \
    ros-jazzy-moveit \
    ros-jazzy-moveit-servo \
    ros-jazzy-moveit-resources-panda-moveit-config \
    ros-jazzy-ros2-control \
    ros-jazzy-ros2-controllers
COPY . /opt/ros/motion/src/motion
WORKDIR /opt/ros/motion
RUN apt -y -qq update && \
    apt -y -qq install \
    python3-venv
RUN python3 -m venv --system-site-packages /opt/python
RUN /opt/python/bin/python3 -m pip freeze
RUN (cd /opt/ros/motion && /ros_entrypoint.sh colcon build)
RUN echo '#!/bin/bash \n\
set -e -x \n\
source /opt/ros/jazzy/setup.bash \n\
source /opt/ros/motion/install/setup.bash \n\
source /opt/python/bin/activate \n\
parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch moveit_servo demo_ros_api.launch.py" "ros2 service call /servo_node/switch_command_type moveit_msgs/srv/ServoCommandType '\''{command_type: 1}'\''" "ros2 run topic_tools relay /joint_trajectory /panda_arm_controller/joint_trajectory" "ros2 run topic_tools relay /twist /servo_node/delta_twist_cmds" \n\
exit 0' >/entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
