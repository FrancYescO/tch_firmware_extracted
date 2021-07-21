U
    Y��`A%  �                
   @   sF  d dl Z d dlZd dlZd dlZd dlZd dlZd dlmZ d dl	m
Z
mZ d dlmZmZ d dlmZ d dlmZmZmZ d dlmZ dZd	Zd
Zee ZdZee Zdej d ej Zdd� Z dZ!dd� Z"dd� Z#dd� Z$dd� Z%dd� Z&e'dk�rBze�(e � � W n6 e)k
�r@ Z* ze�+de,e*� � W 5 dZ*[*X Y nX dS )�    N)�get_device_serial)�get_properties�get_telemetries)�get_auth_data�get_device_client)�command_handling_init)�time_intervals_init�is_outer_interval_elapsed�time_intervals_close)�IoTHubDeviceClientiX  i  �   �x   zRouter Agent � c                  �   sD  t � d d� } | dkrRztd� t�d� W n$ tk
rP   td� t��  Y nX d}tj�|�}|dkr|t	dd�}|�
�  tt�� �}t�d	| � t	d
d�}|�|� |�
�  t�dt��  � t�dt � d}d}|�r@d}t|�I d H \}}	}
t||	|
�I d H at�rd}�q:q�t�d� d}t�t�I d H  q�tt� |�rXtt� d}dadatd� tj}t|�I d H  |�r�dat�r*t d7 a t�dtt � � t t!k�r*t�d� t"�  d}q�nfda td7 att#k�r*t�dttt$ � d � t�rt�d� t"�  d}nt�d� t�%� I d H  q�t�t$�I d H  �qdq�d S )N�   ZCPz$Change the current working Directoryz/Acotel_UA/z*Can't change the Current Working DirectoryzAcotel_run.logi'  �wzCurrent PID z/tmp/acotel/agent.pidzCurrent Working Directory zSTART TFz g_device_client is None... retryr   r   z2send_message() in progress while CONNECTION is UP z>send_message() BLOCKED with CONNECTION UP: exiting applicationzConnection DOWN for z secondszDsend_message() in progress with CONNECTION DOWN: exiting applicationzXsend_message() NOT in progress with CONNECTION DOWN : execute g_device_client.shutdown())&r   �print�os�chdir�OSError�sys�exit�path�getsize�open�close�str�getpid�tracer�Info�write�getcwd�strAGENT_VERSIONr   r   �g_device_client�asyncio�sleep�LOGIN_RETRY_SECONDSr   r   �periodic_data_send�b_send_in_progressZconn_down_readings�conn_state_display_init�	connected�conn_state_display�send_in_progress_readings�SEND_IN_PROGRESS_MAX_READINGSr
   �CONNECTION_DOWN_MAX_READINGS�CONNECTION_CHECK_PERIOD_SECONDSZshutdown)Zdevice_typeZLogFilenameZSize�fZPIDZb_first_initZb_runZb_remove_saved_auth_dataZcert�keyZdeviceZb_device_client_connected� r1   �	./main.py�main@   s~    








r3   �
   c                 C   s   | a dad S )Nr   )�gb_conn_prev_state�skip_display_cnt)Zb_prev_state_initr1   r1   r2   r(   �   s    r(   c                 �   sF   | t kr,td7 attkrBdat| �I d H  nt| � t| �I d H  d S )Nr   r   )r5   r6   �SKIP_DISPLAY_NUM�conn_state_display_helperr(   )�b_stater1   r1   r2   r*   �   s    r*   c                 �   s$   | r
d}nd}t �dt|� � d S )NZUPZDOWNzCONNECTION IS )r   r   r   )r9   Z	str_stater1   r1   r2   r8   �   s    r8   c               
   �   s@  t j�r2z\t�d� t� I d H } t�d� t�d|  � t| �I d H rRt�d� nt�d� W d S W n4 tk
r� } zt�dt|� � W 5 d }~X Y nX t� �r<zVt�d� t	� I d H }t�d� t�d	| � t|�I d H r�t�d
� n
t�d� W n6 tk
�r. } zt�dt|� � W 5 d }~X Y nX n
t�d� d S )NzBefore retrieving telemetrieszAfter retrieving telemetrieszTelemetries message to sendz%Telemetries message successfully sentz Telemetries message send failurez!periodic_data_send() exception : zBefore retrieving propertieszAfter retrieving propertieszProperties message to sendz$Properties message successfully sentzProperties message send failurez9periodic_data_send() : CONNECTION IS DOWN, skip data send)
r"   r)   r   r   r   �	data_send�	Exceptionr   r	   r   )Ztelemetries�errZ
propertiesr1   r1   r2   r&   �   s0    



$

&r&   c              
   �   sb   da dazt�| �I d H  d}W n8 tk
rX } zt�dt|� � d}W 5 d }~X Y nX da|S )Nr   TzSend exception : F)r+   r'   r"   Zsend_messager;   r   r   r   )�dataZb_resultr<   r1   r1   r2   r:   !  s    r:   �__main__z asyncio.run(main()) exception : )-r   r   r#   �
subprocessZTRACERr   Zuainfo�serialr   Z	datamodelr   r   Zauthr   r   Zcommandr   Ztimeintervalr   r	   r
   Zazure.iot.device.aior   r%   ZCONNECTION_DOWN_MAX_SECONDSr.   r-   ZSEND_IN_PROGRESS_MAX_SECONDSr,   Z
DEVICE_VERZFACTORY_DATEr!   r3   r7   r(   r*   r8   r&   r:   �__name__�runr;   r<   r   r   r1   r1   r1   r2   �<module>   s>    )
