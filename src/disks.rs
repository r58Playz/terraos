use libblkid_rs::{BlkidCache, BlkidErr, BlkidPartition, BlkidProbe};
use std::io::Read;

pub fn get_kernel_uuid_from_cmdline(file: &str) -> std::io::Result<Option<String>> {
    let mut file = std::fs::File::open(file)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;

    for arg in contents.split(' ') {
        if arg.contains("kern_guid") {
            let uuid = arg.split('=').nth(1);
            if let Some(kern_uuid) = uuid {
                let kern_uuid_string = kern_uuid.to_string();
                return Ok(Some(kern_uuid_string));
            }
        }
    }

    Ok(None)
}

pub fn get_disk_from_part(block_device: &str) -> std::io::Result<String> {
    let input_path = std::path::PathBuf::from(block_device); 
    let block_device_name_oss = match input_path.file_name() {
        Some(name) => name,
        None => return Err(std::io::Error::new(std::io::ErrorKind::Other, "Unable to get block device name")),
    };
    let block_device_name = match block_device_name_oss.to_str() {
        Some(name) => name,
        None => return Err(std::io::Error::new(std::io::ErrorKind::Other, "Unable to get str from OsStr")),
    };

    let mut sys_block_link = std::fs::read_link(std::path::PathBuf::from(format!("/sys/class/block/{}", block_device_name)))?;

    sys_block_link.pop();

    let disk_oss = match sys_block_link.file_name() {
        Some(name) => name,
        None => return Err(std::io::Error::new(std::io::ErrorKind::Other, "Unable to get disk filename")),
    };
    let disk = match disk_oss.to_str() {
        Some(name) => name,
        None => return Err(std::io::Error::new(std::io::ErrorKind::Other, "Unable to get str from OsStr")),
    };

    Ok(format!("/dev/{}", disk))
}

pub fn search_for_tag(name: String, uuid: String) -> libblkid_rs::Result<String> {
    let mut cache = BlkidCache::get_cache(None)?;

    cache.probe_all()?;
    cache.probe_all_removable()?;
    cache.gc_cache();

    let dev = cache.find_dev_with_tag(name.as_str(), uuid.as_str())?;
    let devname = dev.devname()?;

    let devstr = devname.into_os_string().into_string();
    match devstr {
        Ok(str) => Ok(str),
        _ => Err(BlkidErr::Other(
            "Failed to extract string from devname".to_string(),
        )),
    }
}

pub fn scan_for_devices() -> Vec<String> {
    let dir = std::fs::read_dir("/sys/block").expect("Failed to open /sys/block");
    let mut devices: Vec<String> = Vec::new();
    for entry in dir {
        devices.push(format!(
            "/dev/{}",
            entry
                .expect("Failed to read entry in /sys/block")
                .file_name()
                .into_string()
                .expect("Failed to get filename of entry in /sys/block")
        ));
    }
    devices
}

#[derive(Clone, Debug)]
pub struct RootPartition {
    pub partition: String,
    pub label: String,
}

fn probe_partition(partition: BlkidPartition) -> libblkid_rs::Result<RootPartition> {
    let puuid = match partition.get_uuid()? {
        Some(uuid) => uuid,
        None => return Err(BlkidErr::Other("No partition uuid found".to_string())),
    };

    let ptype = partition.get_type_string()?;
    if ptype != "3cb8e202-3b7e-47dd-8a3c-7ff2a13cfcec" {
        return Err(BlkidErr::Other(format!("Not cros rootfs type uuid: {:?} type: {:?}", puuid, ptype)));
    }

    let pname = match partition.get_name()? {
        Some(name) => name,
        None => "No Name".to_string(),
    };

    let pdev = search_for_tag("PARTUUID".to_string(), puuid.to_string())?;

    Ok(RootPartition {
        partition: pdev,
        label: pname,
    })
}

fn probe_device(device: String) -> libblkid_rs::Result<Vec<RootPartition>> {
    let mut probe = BlkidProbe::new_from_filename(std::path::Path::new(&device))?;

    probe.enable_superblocks(false)?;
    probe.enable_partitions(true)?;
    probe.enable_topology(false)?;

    probe.do_fullprobe()?;

    if probe.lookup_value("PTTYPE")? != "gpt" {
        return Err(BlkidErr::Other(
            "Partition table type is not GPT".to_string(),
        ));
    }

    let mut partitions = probe.get_partitions()?;

    let mut rootparts: Vec<RootPartition> = Vec::new();

    for partnum in 0..partitions.number_of_partitions()? {
        let Ok(blkidpart) = partitions.get_partition(partnum) else {
            continue;
        };
        let Ok(part) = probe_partition(blkidpart) else {
            continue;
        };
        rootparts.push(part);
    }
    Ok(rootparts)
}

fn probe_device_result(device: String) -> libblkid_rs::Result<Vec<libblkid_rs::Result<RootPartition>>> {
    let mut probe = BlkidProbe::new_from_filename(std::path::Path::new(&device))?;

    probe.enable_superblocks(false)?;
    probe.enable_partitions(true)?;
    probe.enable_topology(false)?;

    probe.do_fullprobe()?;

    if probe.lookup_value("PTTYPE")? != "gpt" {
        return Err(BlkidErr::Other(
            "Partition table type is not GPT".to_string(),
        ));
    }

    let mut partitions = probe.get_partitions()?;

    let mut rootparts: Vec<libblkid_rs::Result<RootPartition>> = Vec::new();

    for partnum in 0..partitions.number_of_partitions()? {
        let Ok(blkidpart) = partitions.get_partition(partnum) else {
            continue;
        };
        let part = probe_partition(blkidpart);
        rootparts.push(part);
    }
    Ok(rootparts)
}

pub fn scan_for_usable_root_partitions_result() -> Vec<libblkid_rs::Result<Vec<libblkid_rs::Result<RootPartition>>>> {
    let devices = scan_for_devices();

    let mut rootparts: Vec<libblkid_rs::Result<Vec<libblkid_rs::Result<RootPartition>>>> = Vec::new();

    for device in devices {
        let devrootparts = probe_device_result(device);
        rootparts.push(devrootparts);
    }

    rootparts
}

pub fn scan_for_usable_root_partitions() -> Vec<RootPartition> {
    let devices = scan_for_devices();

    let mut rootparts: Vec<RootPartition> = Vec::new();

    for device in devices {
        let Ok(mut devrootparts) = probe_device(device) else {
            continue;
        };
        rootparts.append(&mut devrootparts);
    }

    rootparts
}

pub fn get_squashfs_files_in_directory(path: &str) -> std::io::Result<Vec<String>> {
    let entries = std::fs::read_dir(path)?;

    let file_names: Vec<String> = entries
        .filter_map(|entry| {
            let path = entry.ok()?.path();
            if path.is_file() && path.file_name()?.to_str()?.ends_with(".squashfs") {
                path.file_name()?.to_str().map(|s| s.to_owned())
            } else {
                None
            }
        })
        .collect();

    Ok(file_names)
}
