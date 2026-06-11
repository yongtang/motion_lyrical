FROM nvcr.io/nvidia/deepstream:9.0-triton-multiarch
RUN locale  # check for UTF-8
RUN sudo apt update && sudo apt install locales && \
    sudo locale-gen en_US en_US.UTF-8 && \
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN locale  # verify settings
RUN sudo apt install software-properties-common -y && \
    sudo add-apt-repository universe -y
RUN sudo apt update && sudo apt install curl -y && \
    export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" && \
    sudo dpkg -i /tmp/ros2-apt-source.deb
RUN sudo apt update && sudo apt install ros-jazzy-ros-base -y

RUN apt -y -qq update && \
    apt -y -qq install \
    parallel \
    ros-jazzy-ros2-control \
    ros-jazzy-moveit-resources-panda-moveit-config \
    ros-jazzy-ur

RUN sudo apt update && sudo apt install ros-dev-tools -y

RUN apt -y -qq update && \
    apt -y -qq install \
    python3-venv
RUN python3 -m venv --system-site-packages /opt/python
RUN /opt/python/bin/python3 -m pip freeze

COPY . /opt/ros/motion/src/motion
WORKDIR /opt/ros/motion
RUN (cd /opt/ros/motion && source /opt/ros/jazzy/setup.bash && colcon build)

RUN echo -e '#!/bin/bash \n\
set -e -x \n\
source /opt/ros/jazzy/setup.bash \n\
source /opt/ros/motion/install/setup.bash \n\
source /opt/python/bin/activate \n\
export PYTHONPATH=/opt/python/lib/python3.12/site-packages:$PYTHONPATH \n\
if [ "${MOTION_ARM}" == "PANDA" ]; then \n\
  echo /panda_arm_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch moveit_resources_panda_moveit_config demo.launch.py" "ros2 run motion motion" \n\
elif [ "${MOTION_ARM}" == "UR20" ]; then \n\
  echo /scaled_joint_trajectory_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur20 robot_ip:=192.168.0.2 use_mock_hardware:=true launch_rviz:=false" "ros2 run motion motion" \n\
elif [ "${MOTION_ARM}" == "UR30" ]; then \n\
  echo /scaled_joint_trajectory_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur30 robot_ip:=192.168.0.2 use_mock_hardware:=true launch_rviz:=false" "ros2 run motion motion" \n\
fi \n\
exit 0' >/entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
