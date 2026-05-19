FROM ros:jazzy
RUN apt -y -qq update && \
    apt -y -qq install \
    parallel \
    ros-jazzy-ros2-control \
    ros-jazzy-moveit-resources-panda-moveit-config \
    ros-jazzy-ur
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
if [ "${MOTION_ARM}" == "PANDA" ]; then \n\
  echo /panda_arm_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch moveit_resources_panda_moveit_config demo.launch.py" \n\
elif [ "$${MOTION_ARM}" == "UR20" ]; then \n\
  echo /scaled_joint_trajectory_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur20 robot_ip:=192.168.0.2 use_mock_hardware:=true launch_rviz:=false" \n\
elif [ "$${MOTION_ARM}" == "UR20" ]; then \n\
  echo /scaled_joint_trajectory_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur30 robot_ip:=192.168.0.2 use_mock_hardware:=true launch_rviz:=false" \n\
fi \n\
exit 0' >/entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
